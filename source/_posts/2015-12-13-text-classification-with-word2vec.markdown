---
layout: post
title: "Text classification with Word2Vec"
date: 2015-12-13 17:18:58 +0000
comments: true
categories: 
---
In the previous post I talked about usefulness of topic models for non-NLP tasks, it's back to NLP-land this time. I investigate several ways of using word embeddings for text classification and TL;DR: taking a mean vector of words in a text and feeding it into a random forest works pretty well. 

The basic idea is that semantic vectors (such as the ones provided by Word2Vec) should preserve most of the relevant information about a text while having relatively low dimensionality which allows better machine learning treatment than straight one-hot encoding of words. Another advantage of topic models is that they are unsupervised so it can help when labaled data is scarce. Say you only have one thousand manually classified blog posts but a million unlabeled ones. A high quality topic model can be trained on the full set of one million. If you can use topic modeling-derived features in your classification, you will be benefitting from your collection of texts, not just the labeled ones. 

####The (python) meat
Ok, word embeddings are awesome, how do we use them? Train the model first:
    import gensim
    # let X be a list of tokenized texts (i.e. list of lists of tokens)
    model = gensim.models.Word2Vec(X, size=100)
    w2v = dict(zip(model.index2word, model.syn0))
We got ourselves a dictionary mapping word -> 100-dimensional vector. Now we can use it to build features. The simplest way to do that is by averaging word vectors for all words in a text.
    class MeanVectorizer(object):
        def __init__(self, w2v):
            self.w2v = w2v
    
        def fit(self, X, y):
            return self
    
        def transform(self, X):
            return np.array([
                np.mean([self.w2v[t] for t in x if t in self.w2v], axis=0)
                for x in X
            ])


I benchmarked on 
http://www.cs.umb.edu/~smimarog/textmining/datasets/