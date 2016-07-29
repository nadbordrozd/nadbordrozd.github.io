---
layout: post
title: "datamatching part 2: spark pipeline"
date: 2016-07-22 22:57:45 +0100
comments: true
categories: 
---
In the [last post](http://nadbordrozd.github.io/blog/2016/07/12/datamatching-part-1/) I talked about the principles of datamatching, now it's time to put them into practice. I will present a generic, customisable Spark pipeline for datamatching as well as a specific instance of it that for matching the toy datasets from the last post. TL;DR of the last post:

To match two datasets:

1. Tokenize corresponding fields in both datasets
2. Group records having a token in common (think SQL join)
3. Compare records withing a group and choose the closest match

###Why spark
This datamatching algorithm could easily be implemented in the traditional single-machine, single-threaded way using a collection of hashmaps. In fact this is what I have done on more than one occasion and it worked. The advantage of spark here is built-in scalability. If your datasets get ten times bigger, just invoke spark requesting ten times as many cores. If matching is taking too long - throw some more resources at it again. In the single-threaded model all you can do is up the RAM as your data grows but the computation is taking longer and longer and there is nothing you can do about it. 

As an added bonus, I discovered that the abstractions Spark forces on you - maps, joins, reduces - are actually appropriate for this problem and encourage a better design than the naive implementation.

### Example data
In the spirit of TDD, let's start by creating a test case. It will consist of two RDDs that we are going to match. Spark's dataframes would be even more natural choice if not for the fact that they are completely fucked up. 

```python
# the first dataset from now on refered to as "left"
left = [
    {
        'Id': 1,
        'name': 'Bruce Wayne',
        'address': '1007 Mountain Drive, Gotham',
        'phone': "01234567890",
        'company': "Wayne Enterprises"
    },
    {
        'Id': 2,
        'name': "Thomas Wayne",
        'address': 'Gotham Cemetery',
        'phone': None,
        'company': 'Wayne Enterprises'
    },
    {
        'Id': 3,
        'name': 'Bruce Banner',
        'address': '56431 Some Place, New Mexico',
        'phone': None,
        'company': 'U.S. Department of Defense'
    }
]

# and the second "right"
right = [
    {
        'Id': 'a',
        'name': 'Wayne, Burce',
        'postcode': None,
        'personal phone': None,
        'business phone': '+735-123-456-7890',
    },
    {
        'Id': 'b',
        'name': 'B. Banner',
        'postcode': '56431',
        'personal phone': '897654322',
        'business phone': None
        
    }, 
    {
        'Id': 'c',
        'name': 'Pennyworth, Alfred',
        'postcode': '1007',
        'personal phone': None,
        'business phone': None
    }
]

# sc is an instance of pyspark.SparkContext
left_rdd = sc.parallelize(left)
right_rdd = sc.parallelize(right)
```

### Tokenizers
First step in the algorithm - tokenize the fields. After all this talk in the last post about fancy tokenizers, for our particular toy datasets we will use extremely simplistic ones:

```python
# lowercase the name and split on spaces, remove non-alphanumeric chars
def tokenize_name(name):
    clean_name = "".join(c if c.isalnum() else " " for c in name)
    return clean_name.lower().split()

# same tokenizers as for names, meh, good enough
def tokenize_address(address):
    return tokenize_name(address)

# last 10 digits of phone number
def tokenize_phone(phone):
    return ["".join(c for c in phone if c in '1234567890')[-10:]]
```

Now we have to specify which tokenizer should be applied to which field. You don't want to use the phone tokenizer on a person's name or vice versa. Also, tokens extracted from name shouldn't mix with tokens from address or phone number. On the other hand, there may be multiple fields that you want to extract e.g. phone numbers from - and these tokens _should_ mix. Here's minimalistic syntax for specifying these things:

```python
# original column name goes first, then token type, then tokenizer function
# for the left dataset
left_tokenizers = [
    ('name', 'name_tokens', tokenize_name),
    ('address', 'address_tokens', tokenize_address),
    ('phone', 'phone_tokens', tokenize_phone)
]

# and right
right_tokenizers = [
    ('name', 'name_tokens', tokenize_name),
    ('postcode', 'address_tokens', tokenize_address),
    ('personal phone', 'phone_tokens', tokenize_phone),
    ('business phone', 'phone_tokens', tokenize_phone)
]
```

And here's how they are applied:

```python
id_key = "Id"
def prepare_join_keys(record, tokenizers):
    for source_column, key_name, tokenizer in tokenizers:
        if record.get(source_column):
            for token in set(tokenizer(record.get(source_column))):
                yield ((token, key_name), record[id_key])

# Ids of records in the left dataset keyed by tokens extracted from the record
left_keyed = left_rdd.flatMap(lambda x: prepare_join_keys(x, left_tokenizers))
# and same for the right dataset
right_keyed = right_rdd.flatMap(lambda x: prepare_join_keys(x, right_tokenizers))
```

The result is a mapping of token -> Id in the form of an RDD. One for each dataset:

```text
>>> left_keyed.collect()
[(('bruce', 'name_tokens'), 1),
 (('wayne', 'name_tokens'), 1),
 (('1007', 'address_tokens'), 1),
 (('mountain', 'address_tokens'), 1),
 (('gotham', 'address_tokens'), 1),
 (('drive', 'address_tokens'), 1),
 (('1234567890', 'phone_tokens'), 1),
 (('thomas', 'name_tokens'), 2),
 (('wayne', 'name_tokens'), 2),
 (('gotham', 'address_tokens'), 2),
 (('cemetery', 'address_tokens'), 2),
 (('bruce', 'name_tokens'), 3),
 (('banner', 'name_tokens'), 3),
 (('place', 'address_tokens'), 3),
 (('mexico', 'address_tokens'), 3),
 (('some', 'address_tokens'), 3),
 (('56431', 'address_tokens'), 3),
 (('new', 'address_tokens'), 3)]
>>> right_keyed.collect()
[(('wayne', 'name_tokens'), 'a'),
 (('burce', 'name_tokens'), 'a'),
 (('1234567890', 'phone_tokens'), 'a'),
 (('b', 'name_tokens'), 'b'),
 (('banner', 'name_tokens'), 'b'),
 (('56431', 'address_tokens'), 'b'),
 (('897654322', 'phone_tokens'), 'b'),
 (('pennyworth', 'name_tokens'), 'c'),
 (('alfred', 'name_tokens'), 'c'),
 (('1007', 'address_tokens'), 'c')]
```

### Generating candidate matches
Now comes the time to generate candidate matches. We do that by joining records that have a token in common:

```python
candidates = (
    left_keyed.join(right_keyed)
    .map(lambda ((token, key), (l_id, r_id)): ((l_id, r_id), {key}))
    .reduceByKey(lambda a, b: a.union(b))
)
```

Result:

```text
>>> candidates.collect()
[((2, 'a'), {'name_tokens'}),
 ((1, 'c'), {'address_tokens'}),
 ((1, 'a'), {'name_tokens', 'phone_tokens'}),
 ((3, 'b'), {'address_tokens', 'name_tokens'})]
```

With every match we have retained the information about what it was joined on for later use. We have 4 candidate matches here - 2 correct and 2 wrong ones. The spurious matches are `(1, 'c')` - Bruce Wayne and Alfred Pennyworth matched due to shared address; `(2, 'a')` - Bruce Wayne and Thomas Wayne matched because of the shared last name.

Joining the original records back to the matches, so they can be compared:

```python
# let's join back 
cand_matches = (
    candidates
    .map(lambda ((l_id, r_id), keys): (l_id, (r_id, keys)))
    .join(left_rdd.keyBy(lambda x: x[id_key]))
    .map(lambda (l_id, ((r_id, keys), l_rec)): (r_id, (l_rec, keys)))
    .join(right_rdd.keyBy(lambda x: x[id_key]))
    .map(lambda (r_id, ((l_rec, keys), r_rec)): (l_rec, r_rec, list(keys)))
)
```

### Finding the best match
We're almost there. Now we need to define a function to evaluate goodness of a match. Take a pair of records and say how similar they are. We will cop out of this by just using the join keys that were retained with every match. The more different types of tokens were matched, the better:

```python
def score_match(left_rec, right_rec, keys):
    return len(keys)
```

We also need a function that will say: a match must be scored at least this high to qualify.

```python
def is_good_enough_match(match_score):
    return match_score >= 2
```

And now, finally we use those functions to evaluate and filter candidate matches and return the matched dataset:

```python
final_matches = (
    cand_matches
    .map(lambda (l_rec, r_rec, keys): 
         (l_rec, r_rec, score_match(l_rec, r_rec, keys)))
    .filter(lambda (l_rec, r_rec, score): is_good_enough_match(score))
)
```

The result:

```text
>>> final_matches.collect()
[({'Id': 1,
   'address': '1007 Mountain Drive, Gotham',
   'company': 'Wayne Enterprises',
   'name': 'Bruce Wayne',
   'phone': '01234567890'},
  {'Id': 'a',
   'business phone': '+735-123-456-7890',
   'name': 'Wayne, Burce',
   'personal phone': None,
   'postcode': None},
  2),
 ({'Id': 3,
   'address': '56431 Some Place, New Mexico',
   'company': 'U.S. Department of Defense',
   'name': 'Bruce Banner',
   'phone': None},
  {'Id': 'b',
   'business phone': None,
   'name': 'B. Banner',
   'personal phone': '897654322',
   'postcode': '56431'},
  2)]
```

Glorious.

### Putting it all together
Now is the time to put "generic" back in the "generic datamatching pipeline in spark". 

```python
class DataMatcher(object):
    def score_match(self, left_rec, right_rec, keys):
        return len(keys)

    def is_good_enough_match(self, match_score):
        return match_score >= 2
    
    def get_left_tokenizers(self):
        raise NotImplementedError()
        
    def get_right_tokenizers(self):
        raise NotImplementedError()
        
    def match_rdds(self, left_rdd, right_rdd):
        left_tokenizers = self.get_left_tokenizers()
        right_tokenizers = self.get_right_tokenizers()

        id_key = "Id"
        
        def prepare_join_keys(record, tokenizers):
            for source_column, key_name, tokenizer in tokenizers:
                if record.get(source_column):
                    for token in set(tokenizer(record.get(source_column))):
                        yield ((token, key_name), record[id_key])

        left_keyed = left_rdd.flatMap(lambda x: prepare_join_keys(x, left_tokenizers))
        right_keyed = right_rdd.flatMap(lambda x: prepare_join_keys(x, right_tokenizers))

        candidates = (
            left_keyed.join(right_keyed)
            .map(lambda ((token, key), (l_id, r_id)): ((l_id, r_id), {key}))
            .reduceByKey(lambda a, b: a.union(b))
        )

        # joining back original records so they can be compared
        cand_matches = (
            candidates
            .map(lambda ((l_id, r_id), keys): (l_id, (r_id, keys)))
            .join(left_rdd.keyBy(lambda x: x[id_key]))
            .map(lambda (l_id, ((r_id, keys), l_rec)): (r_id, (l_rec, keys)))
            .join(right_rdd.keyBy(lambda x: x[id_key]))
            .map(lambda (r_id, ((l_rec, keys), r_rec)): (l_rec, r_rec, list(keys)))
        )

        def score_match(left_rec, right_rec, keys):
            return len(keys)

        def is_good_enough_match(match_score):
            return match_score >= 2

        final_matches = (
            cand_matches
            .map(lambda (l_rec, r_rec, keys): 
                 (l_rec, r_rec, score_match(l_rec, r_rec, keys)))
            .filter(lambda (l_rec, r_rec, score): is_good_enough_match(score))
        )
        
        return final_matches
```

To use it, you have to inherit from `DataMatcher` and override at a minimum the `get_left_tokenizers` and `get_right_tokenizers` functions. You will probably want to override `score_match` and `is_good_enough_match` as well, but the default should work in simple cases.

Now we can match our toy datasets in a few lines oc code, like this:

```python
class ComicBookMatcher(DataMatcher):
    def get_left_tokenizers(self):
        return [
            ('name', 'name_tokens', tokenize_name),
            ('address', 'address_tokens', tokenize_address),
            ('phone', 'phone_tokens', tokenize_phone)
        ]

    def get_right_tokenizers(self):
        return [
            ('name', 'name_tokens', tokenize_name),
            ('postcode', 'address_tokens', tokenize_address),
            ('personal phone', 'phone_tokens', tokenize_phone),
            ('business phone', 'phone_tokens', tokenize_phone)
        ]

cbm = ComicBookMatcher()

final_matches = cbm.match_rdds(left_rdd, right_rdd)
```

Short and sweet.

There are some optimisations that can be done to improve speed of the pipeline, I omitted them here for clarity. More importantly, in any nontrivial usecase you will want to use a more sophisticated evaluation function than the default one. This will be the subject of the next post.