---
layout: post
title: "Data engineers will hate you - one weird trick to fix your pyspark schemas"
date: 2016-05-22 21:39:15 +0100
comments: true
categories: [spark, pyspark, dataframes, sqlContext, schemas]
keywords: [spark, pyspark, dataframes, sqlContext, schemas]
---

I will share with you a snippet that took out a lot of misery from my dealing with pyspark dataframes. This is pysparks-specific. Nothing to see here if you're not a pyspark user. The first two sections consist of me complaining about schemas and the remaining two offer what I think is a neat way of creating a schema from a dict (or a dataframe from an rdd of dicts).

####The Good, the Bad and the Ugly of dataframes
Dataframes in pyspark are simultaneously pretty great and <del>kind of</del> completely broken. 

- they enforce a schema
- you can run SQL queries against them
- faster than rdd
- much smaller than rdd when stored in parquet format

On the other hand:

- dataframe join sometimes gives [wrong results](https://issues.apache.org/jira/browse/SPARK-10892)
- pyspark dataframe outer join acts as an inner join
- when cached with `df.cache()` dataframes sometimes start throwing `key not found` and Spark driver dies. Other times the task succeeds but the the underlying rdd becomes corrupted (field values switched up).
- not really dataframe's fault but related - parquet is not human readable which sucks - can't easily inspect your saved dataframes

But the biggest problem is actually transforming the data. It works perfectly on those contrived examples from the tutorials. But I'm not working with flat SQL-table-like datasets. Or if I am, they are already in some SQL database. When I'm using Spark, I'm using it to work with messy multilayered json-like objects. If I had to create a UDF and type out a ginormous schema for every transformation I want to perform on the dataset, I'd be doing nothing else all day, I'm not even joking. UDFs in pyspark are clunky at the best of times but in my typical usecase they are unusable. Take this, relatively tiny record for instance:
```python
record = {
    'first_name': 'nadbor',
    'last_name': 'drozd',
    'occupation': 'data scientist',
    'children': [
        {
            'name': 'Lucja',
            'age': 3,
            'likes cold showers': True
        }
    ]
}
```
the correct schema for this is created like this:
```python
from pyspark.sql.types import StringType, StructField, StructType, BooleanType, ArrayType, IntegerType
schema = StructType([
        StructField("first_name", StringType(), True),
        StructField("last_name", StringType(), True),
        StructField("occupation", StringType(), True),
        StructField("children", ArrayType(
            StructType([
                StructField("name", StringType(), True),
                StructField("age", IntegerType(), True),
                StructField("likes cold schowers", BooleanType(), True)
            ])
        ), True)
    ])
```
And this is what I would have to type every time I need a udf to return such record - which can be many times in a single spark job.

####Dataframe from an rdd - how it is
For these reasons (+ legacy json job outputs from hadoop days) I find myself switching back and forth between dataframes and rdds. Read some JSON dataset into an rdd, transform it, join with another, transform some more, convert into a dataframe and save as parquet. Or read some parquet files into a dataframe, convert to rdd, do stuff to it, convert back to dataframe and save as parquet again. This workflow is not so bad - I get the best of both worlds by using rdds and dataframes only for the things they're good at. How do you go from a dataframe to an rdd of dictionaries? This part is easy:
```python
rdd = df.rdd.map(lambda x: x.asDict())
```
It's the other direction that is problematic. You would think that rdd's method `toDF()` would do the job but no, it's broken.
```python
df = rdd.toDF()
```
actually returns a dataframe with the following schema (`df.printSchema()`):
```text
root
 |-- children: array (nullable = true)
 |    |-- element: map (containsNull = true)
 |    |    |-- key: string
 |    |    |-- value: boolean (valueContainsNull = true)
 |-- first_name: string (nullable = true)
 |-- last_name: string (nullable = true)
 |-- occupation: string (nullable = true)
```

It interpreted the inner dictionary as a `map` of `boolean` instead of a `struct` and *silently dropped* all the fields in it that are not booleans. But this method is deprecated now anyway. The preferred, official way of creating a dataframe is with an rdd of `Row` objects. So let's do that.
```python
from pyspark.sql import Row
rdd_of_rows = rdd.map(lambda x: Row(**x))
df = sql.createDataFrame(rdd_of_rows)
df.printSchema()
```
prints the same schema as the previous method. 

In addition to this, both these methods will fail completely when some field's type cannot be determined because all the values happen to be null in some run of the job.

Also, quite bizarrely in my opinion, order of columns in a dataframe is significant while the order of keys is not. So if you have a pre-existing schema and you try contort an rdd of dicts into that schema, you're gonna have a bad time.

#### How it should be
Without further ado, this is how I now create my dataframes:
```python
# this is what a typical record in the rdd looks like
prototype = {
    'first_name': 'nadbor',
    'last_name': 'drozd',
    'occupation': 'data scientist',
    'children': [
        {
            'name': 'Lucja',
            'age': 3,
            'likes cold showers': True
        }
    ]
}
df = df_from_rdd(rdd, prototype, sqlContext)
```

This doesn't randomly break, doesn't drop fields and has the right schema. And I didn't have to type any of this `StructType([StructField(...` nonsense, just plain python literal that I got by running
```python
print rdd.first()
```

As an added bonus now this prototype is prominently displayed at the top of my job file and I can tell what the output of the job looks like without having to decode parquet files. Self documenting code FTW!

#### How to get there
And here's how it's done. First we need to implement our own schema inference - the way it should work:

```python
import pyspark.sql.types as pst
from pyspark.sql import Row

def infer_schema(rec):
    """infers dataframe schema for a record. Assumes every dict is a Struct, not a Map"""
    if isinstance(rec, dict):
        return pst.StructType([pst.StructField(key, infer_schema(value), True)
                              for key, value in sorted(rec.items())])
    elif isinstance(rec, list):
        if len(rec) == 0:
            raise ValueError("can't infer type of an empty list")
        elem_type = infer_schema(rec[0])
        for elem in rec:
            this_type = infer_schema(elem)
            if elem_type != this_type:
                raise ValueError("can't infer type of a list with inconsistent elem types")
        return pst.ArrayType(elem_type)
    else:
        return pst._infer_type(rec)
```

Using this we can now specify the schema using a regular python object - no more java-esque abominations. But this is not all. We will also need a function that transforms a python dict into a rRw object with the correct schema. You would think that this should be automatic as long as the dict has all the right fields, but no - order of fields in a Row is significant, so we have to do it ourselves.
 
```python
def _rowify(x, prototype):
    """creates a Row object conforming to a schema as specified by a dict"""

    def _equivalent_types(x, y):
        if type(x) in [str, unicode] and type(y) in [str, unicode]:
            return True
        return isinstance(x, type(y)) or isinstance(y, type(x))

    if x is None:
        return None
    elif isinstance(prototype, dict):
        if type(x) != dict:
            raise ValueError("expected dict, got %s instead" % type(x))
        rowified_dict = {}
        for key, val in x.items():
            if key not in prototype:
                raise ValueError("got unexpected field %s" % key)
            rowified_dict[key] = _rowify(val, prototype[key])
            for key in prototype:
                if key not in x:
                    raise ValueError(
                        "expected %s field but didn't find it" % key)
        return Row(**rowified_dict)
    elif isinstance(prototype, list):
        if type(x) != list:
            raise ValueError("expected list, got %s instead" % type(x))
        return [_rowify(e, prototype[0]) for e in x]
    else:
        if not _equivalent_types(x, prototype):
            raise ValueError("expected %s, got %s instead" %
                             (type(prototype), type(x)))
        return x
```

And finally:

```python
def df_from_rdd(rdd, prototype, sql):
    """creates a dataframe out of an rdd of dicts, with schema inferred from a prototype record"""
    schema = infer_schema(prototype)
    row_rdd = rdd.map(lambda x: _rowify(x, prototype))
    return sql.createDataFrame(row_rdd, schema)
```