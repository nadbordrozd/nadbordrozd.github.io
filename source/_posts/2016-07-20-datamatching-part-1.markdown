---
layout: post
title: "datamatching - part 1: algorithm"
date: 2016-07-12 21:59:14 +0100
comments: true
categories: 
---
In this and the next post I will explain the basics of datamatching and give an implementation of a bare-bones datamatching pipeline in pyspark.

###Datamatching
You have a dataset of - let's say - names and addresses of some group of people. You want to enrich it with information scraped from e.g. linkedin or wikipedia. How do you figure out which scraped profiles match wich records in your database?

Or you have two datasets of sales leads maintained by different teams and you need to merge them. You know that there is some overlap between the records but there is no unique identifier that you can join the datasets on. You have to look at the the records themselves to decide if they match.

Or you have a dataset that over that years has collected some duplicate records. How do you dedup it, given that the data format is not consistent and there may be errors in the records?

All of the above are specific cases of a problem that can be described as:
 _Finding all the pairs (groups) of records in a dataset(s) that correspond to the same real-world entity._ 
 
This is what I will mean by datamatching in this post.

This type of task is very common in data science, and I have done it (badly) many times before finally coming up with a generic, clean and scalable solution. There are already many commercial solutions to specific instances of this problem out there and I know of at least two startups whose main product is datamatching. Nevertheless for many usecases a DIY datamatching pipeline should be just as good and may be easier to build than integration with an external service or application.

###An example
The general problem of datamatching will be easier to discuss with a specific example in mind. Here goes:

You work at a company selling insurance to comic book characters. You have a database of 50.000 potential clients (these are the first 3):

```text
  Id  address                       company                     name                phone
----  ----------------------------  --------------------------  ------------  -----------
   1  1007 Mountain Drive, Ogtham   Wayne Enterprises           Bruce Wayne   01234567890
   2  Gotham Cemetery               Wayne Enterprises           Thomas Wayne
   3  56431 Some Place, New Mexico  U.S. Department of Defense  Bruce Banner
```

and you just acquired 400.000 new leads:

```text
Id    business phone     name                  personal phone    postcode
----  -----------------  ------------------  ----------------  ----------
a     +735-123-456-7890  Wayne, Burce
b                        B. Banner                  897654322       56431
c                        Pennyworth, Alfred                          1007
```

You need to reconcile the two tables - find which (if any) records from the second table correspond to records in the first. Unfortunately data in both tables is formatted differently and there are some typos in both ("Burce", "Ogtham"). Nevertheless it is easy for a human being to figure out who is who just by eyeballing the two datasets. $$Id = 1$$ from the first table and $$Id = a$$ from the second clearly refer to the same person - Bruce Wayne. And $$Id = 3$$ matches $$Id =  b$$ - Bruce Banner. The remaining records - Thomas Wayne and Alfred Pennyworth don't have any matches. 

Now, how to do the same automatically and at scale? Comparing every record from one table to every one in the other - $$50k \times 400k = 2 \times 10^9 $$ comparisons - is out of the question.

###The impatient programmer approach
Like any red-blooded programmer, when I see a list of things to be matched to other things, I immediately think: hashmaps. My internal dialogue goes something like this:

- _Let's make a lookup {name -> Id} using the first table and iterate over the second table_   
- But the names are in a different format, they won't match   
- _OK, let's normalize the names first, strip punctuation, put the words in alphabetical order_   
- Still won't match - Bruce Banner is abbreviated to B. Banner in one of the tables   
- _Fair enough. Let's have two separate entries in the lookup for 'Bruce' and 'Banner' both pointing to Id = 3_
- but we don't want to match just any 'Bruce' or  any 'Banner' to this guy
- _Yeah, will have to use the remaining attributes to verify if a match is legit. Generate potential matches by looking up every word in the 'name' field, and validate by checking if the other fields look similar. This should work_
- what if the name is empty or misspeled, but all other fields match up perfectly? Shouldn't this be still considered a match? 
- _Now you're being difficult on purpose! FINE. Let's have multiple lookups - name -> Id, phone -> Id, etc. A pair of records will be considered a potential match if they have at least one of those in common_

This is beginning to sound unwieldy, but it's basically the correct approach and - I strongly suspect - the only workable approach. At least as long as we're not taking the hashmaps too literally. But let's reformulate it in slightly more abstract terms before diving into implementation.

###Generalising
Datamatching must consist of two stages:

1. Generate candidate matches
2. For every record, pick the best match among the candidates

In this post I will assume that we have a good way of evaluating candidate matches (step 2) and concentrate only on step 1. In fact 2 is crucial and usually harder than 1 but it's very case-specific. More on that topic next time.

#### Generating candidates
When is a pair of records a good candidate for a match? When the records have something in common. What? For example one of the fields - like phone number or name or address. That would definitely suffice but it's too restrictive. Consider Bruce Wayne from our example. In the first table:

```python
{
    'Id': 1,
    'name': 'Bruce Wayne',
    'address': '1007 Mountain Drive, Gotham',
    'phone': "01234567890",
    'company': "Wayne Enterprises"
}
```

And in the second table:

```python
{
    'Id': 'a',
    'name': 'Wayne, Burce',
    'postcode': None,
    'personal phone': None,
    'business phone': '+735-123-456-7890',
}
```

Not a single field in common between these two records and yet they clearly represent the same person. 

It is tempting to try to normalise phone numbers by stripping area extensions, fix misspeled names, normalise order of first-, middle-, last name, etc. And sometimes this may be the way to go. But in general it's ambiguous and lossy. 
There will never be a normalisation function that does the right thing for every possible version of the name:
```text
"Bruce Wayne"
"Bruce T. Wayne"
"B.T. Wayne"
"Wayne, Burce"
```

What we can do instead is extract *multiple* tokens (think: multiple hashes) from the name. A pair of records will be considered a candidate match if they have at least one token in common.

We can for example just split the name on whitespaces:

```text
"Bruce Thomas Wayne" -> ["Bruce", "Thomas", "Wayne"]
```
and have this record be matched with every "Bruce" every "Thomas" and every "Wayne" in the dataset. This may or may not be a good idea depending on how many "Bruces" there are in this specific dataset. But tokens don't have to be words. We can try bigrams:

```text
"Bruce Thomas Wayne" -> ["Bruce Thomas", "Thomas Wayne"]
```

Or we can try forming initials:

```text
"Bruce Thomas Wayne" -> ["B.T. Wayne", "B. Wayne", "B.T.W"]
```

If we did that, then for instance both "Bruce Wayne" and "Burce T. Wayne" would get "B. Wayne" as one of the tokens and would end up matched as a result. 

If we tokenize by removing vowels, that would go a long way toward fixing typos and alternative spellings while introducing few false positives:

```text
"Bruce Wayne" -> ["Brc Wyn"]
"Burcee Wayn" -> ["Brc Wyn"]
```

There are also algorithms like [Soundex](https://en.wikipedia.org/wiki/Soundex) that tokenize based on how a word _sounds_ regardless of how it's spelled. Soundex gives the same result for "Bruce" and "Broose" and "Bruise" or for "John" and "Jon". Very useful given that a lot data entry is done by marketers who talk to people (and ask their names) over the phone.

Finally, nothing stops us from using all of the above at the same time:
```text
"Bruce Thomas Wayne" -> ["Bruce Thomas", "Thomas Wayne", "B.T. Wayne", "B. Wayne", "B.T.W", "Brc Wyn", ...]
```

With this, all the different ways of spelling "Bruce Wayne" should get at least one token in common and if we're lucky few other names will. 

This was an overview of name tokenization. Other types of data will require their own tokenization rules. The choice of tokenization logic necessarily depends on the specific data type and dataset but these the general principles:

- tokenization should try to fix ambiguities in the data. If there are multiple ways a real world entity can be represented in the dataset, good tokenizer would give all of them the same token
- tokens should be specific enough records representing different real world entities only rarely get a token in common

One not name-related example: phone numbers. Since people enter phone numbers in databases in one thousand different formats with all kinds of rubbish area codes and extensions you shouldn't count on raw phone numbers matching perfectly. An example of a sensible tokenizer is one that first strips all non-digit characters from the phone number then returns the last 8 digits. 
```text
"+44-1-800-123-4567-890 and ask for Mary" -> ["34567890"]
```
Or to guard against people putting extensions at the end of phone numbers, we can extract _every_ consecutive 8 digits:
```text
"800-555-2222,123" -> ["80055522", "00555222"", "05552222", "55522221", "55222212", "52222123"]
```
This should catch any reasonable way of writing the number while still having very low likelihood of a collision. 

####TL;DR
To match two datasets:

1. Tokenize corresponding fields in both datasets
2. Group records having a token in common (think SQL join)
3. Compare records withing a group and choose the closest match

Coming up: how to implement this in spark.