---
layout: post
title: "datamatching part 3: match scoring"
date: 2016-07-29 20:39:30 +0100
comments: true
categories: 
---
In this post I will share some tips on the final aspect of datamatching that was glossed over in parts [1](http://nadbordrozd.github.io/blog/2016/07/22/datamatching-part-2-spark-pipeline/) and [2](http://nadbordrozd.github.io/blog/2016/07/20/datamatching-part-1/) - scoring matches. This is maybe the hardest part of the process, but it also requires the most domain knowledge so it's hard to give general advice.

### Recap
In the previous posts we started with two datasets "left" and "right". Using tokenization and the magic of spark we generated for every left record a small bunch of right records that maybe correspond to it. For example this record:
```python
{
    'Id': 1,
    'name': 'Bruce Wayne',
    'address': '1007 Mountain Drive, Gotham',
    'phone': '01234567890',
    'company': 'Wayne Enterprises'
}
```
got these two as candidate matches:
```python
{
    'Id': 'a',
    'name': 'Wayne, Burce',
    'postcode': None,
    'personal phone': None,
    'business phone': '+735-123-456-7890',
}
{
    'Id': 'c',
    'name': 'Pennyworth, Alfred',
    'postcode': '1007',
    'personal phone': None,
    'business phone': None
}
```

And now we need to decide which - if any - is(are) the correct one(s). Last time we dodged this problem by using a heuristic "the more keys were matched, the better the candidate". In this case the record with Id `'a'` was matched on both name and phone number while `'c'` was matched on postcode alone, therefore `'a'` is the better match. It worked in our simple example but in general it's not very accurate or robust. Let's try to do better.

### Similarity functions
The obvious first step is to use some string comparison function to get a continuous measure of similarity for the names rather than the binary match - no match. Levenshtein distance will do, Jaro-Winkler is even better.
```python
from jellyfish import jaro_winkler
def name_similarity(left_record, right_record):
    return jaro_winkler(left_record.['name'] or '', right_record['name'] or '')
```

and likewise for the phone numbers, a sensible measure of similarity would be the length of the longest common substring:
```python
from py_common_subseq import find_common_subsequences

def sanitize_phone(phone):
    return ''.join(c for c in (phone or '') if c in '1234567890')

def phone_sim(phone_a, phone_b):
    phone_a = sanitize_phone(phone_a)
    phone_b = sanitize_phone(phone_b)
    
    # if the number is too short, means it's fubar
    if phone_a < 7 or phone_b < 7:
        return 0
    return max(len(sub) for sub in find_common_subsequences(phone_a, phone_b)) \
        / (max(len(phone_a), max(len(phone_b))) or 1)
```

This makes sense at least if the likely source of phone number discrepancies is area codes or extensions. If we're more worried about typos than different prefixes/suffixes then Levenshtein would be the way to go.

Next we need to come up with some measure of postcode similarity. E.g. full match = 1, partial match = 0.5 - for UK postcodes. And again the same for any characteristic that can be extracted from the records in both datasets. 

With all those comparison functions in place, we can create a better scorer:
```python
def score_match(left_record, right_record):
    name_weight = 1
    # phone numbers are pretty unique, give them more weight
    phone_weight = 2
    # postcodes are not very unique, less weight
    postcode_weight = 0.5

    return name_weight * name_similarity(left_record, right_record) \
        + phone_weight * phone_similarity(left_record, right_record) \
        + address_weight * adress_similarity(left_record, right_record)
```

This should already work significantly better than our previous approach but it's still an arbitrary heuristic. Let's see if we can do better still.

### Scoring as classification
Evaluation of matches is a type of classification. Every candidate match is either true or spurious and we use similarity scores to decide which is the case. This dictates a simple approach:

1. Take a hundred or two of records from the left dataset together with corresponding candidates from the right dataset.
2. Hand label every record-candidate pair as true of false.
3. Calculate similarity scores for every pair.
4. Train a classifier model on the labeled examples.
5. Apply the model to the rest of the left-right candidate pairs. Use probabilistic output from the classifier to get a continuous score that can be compared among candidates.

It shouldn't have been a surprise to me but it was when I discovered that this actually works and makes a big difference. Even with just 4 features matching accuracy went up from 80% to over 90% on a benchmark dataset just from switching from handpicked weights to weights fitted with logistic regression. Random forest did even better.

One more improvement that can take accuracy to the next level is iterative learning. You train your model, apply it and see in what situations is the classifier least confident (probability ~50%). Then you pick some of those ambiguous examples, hand-label them and add to the training set, rinse and repeat. If everything goes right, now the classifier has learned to crack previously uncrackable cases.

This concludes my tutorial on datamatching but there is one more tip that I want to share.

### Name similarity trick
Levenshtein distance, Yaro-Winkler distnce etc. are great measures of edit distance but not much else. If the variation in the string you're comparing is due to typos (`"Bruce Wayne"` -> `"Burce Wanye"`) then Levenshtein is the way to go. Frequently though the variation in names has nothing to do with typos at all, there are just multiple ways people refer to the same entity. If we're talking about companies `"Tesco"` is clearly `"Tesco PLC"` and `"Manchester United F.C."` is the same as `"Manchester United"`. Even `"Nadbor Consulting Company"` is very likely at least related to `"Nadbor Limited"` given how unique the word `"Nadbor"` is and how `"Limited"`, `"Company"` and `"Consulting"` are super common to the point of meaninglessness. No edit distance would ever figure that out because it doesn't know anything about the nature of the strings it receives or about their frequency in the dataset. 

A much better distance measure in the case of company names should look at the words the two names have in common, rather than the characters. It should also discount the words according to their uniqueness. The word `"Limited"` occurs in a majority of company names so it's pretty much useless, `"Consulting"` is more important but still very common and `"Nadbor"` is completely unique. Let the code speak for itself:

```python
# token2frequency is just a word counter of all words in all names
# in the dataset
def sequence_uniqueness(seq, token2frequency):
    return sum(1/token2frequency(t)**0.5 for t in seq)

def name_similarity(a, b, token2frequency):
    a_tokens = set(a.split())
    b_tokens = set(b.split())
    a_uniq = sequence_uniqueness(a_tokens)
    b_uniq = sequence_uniqueness(b_tokens)
    
    return sequence_uniqueness(a.intersection(b))/(a_uniq * b_uniq) ** 0.5
```

The above can be interpreted as the scalar product of the names in the Bag of Word representation in the idf space except instead of the logarithm usually used in idf I used a square root because it gives more intuitively appealing scores. I have tested this and it works great on UK company names but I suspect it will do a good job at comparing many other types of sequences of tokens (not necessarily words).