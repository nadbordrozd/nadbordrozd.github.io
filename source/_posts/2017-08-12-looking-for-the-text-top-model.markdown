---
layout: post
title: "Looking for the text top model"
date: 2017-08-12 16:49:56 +0100
comments: true
categories: 
---
_TL;DR: I tested a bunch of neural network architectures plus SVM + NB on several text clasification datasets. Results at the bottom of the post._

Last year I wrote a [post](http://nadbordrozd.github.io/blog/2016/05/20/text-classification-with-word2vec/) about using word embeddings like word2vec or GloVe for text classification. The embeddings in my benchmarks were used in a very crude way - by averaging word vectors for all words in a document and then plugging the result into a Random Forest. Unfortunately, the resulting classifier turned out to be strictly inferior to a good old SVM except in some special circumstances (very few training examples but lots of unlabeled data).

There are of course better ways of utilising word embeddings than averaging the vectors and last month I finally got around to try them. As far as I can tell from a brief survey of arxiv, most state of the art text classifiers use embeddings as inputs to a neural network. But what kind of neural network works best? [LSTM](https://arxiv.org/abs/1607.02501v2)? LSTM? [CNN](https://arxiv.org/pdf/1408.5882v2.pdf)? [BLSTM with CNN](https://arxiv.org/pdf/1611.06639.pdf)? There are doezens of tutorials on the internet showing how to implement this of that neural classfier and testing it on some dataset. The problem with them is that they usually give metrics without a context. Someone says that their achieved 0.85 accuracy on some dataset. Is that good? Should I be impressed? Is it better than Naive Bayes, SVM? Than other neural architectures? Was it a fluke? Does it work as well on other datasets?

To answer those questions, I implemented several network architectures in Keras and created a benchmark where those algorithms compete with classics like SVM and Naive Bayes. [Here it is](https://github.com/nadbordrozd/text-top-model). 

I intend to keep adding new algorithms and dataset to the benchmark as I learn about them. I will update this post when that happens.

### Models
All the models in the repository are wrapped in scikit-learn compatible classes with `.fit(X, y)`, `.predict(X)`, `.get_params(recursive)` and with all the layer sizes, dropout rates, n-gram ranges etc. parametrised. The snippets below are simplified for clarity.

Since this was supposed to be a benchmark of classifiers, not of preprocessing methods, all datasets come already tokenised and the classifier is given a list of token ids, not a string.

#### Naive Bayes
Naive Bayes comes in two varieties - Bernoulli and Multinomial. We can also use tf-idf weighting or simple counts and we can include n-grams. Since sklearn's vectorizer expects a string and will be giving it a list of integer token ids, we will have to override the default preprocessor and tokenizer. 

```python
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer
from sklearn.naive_bayes import BernoulliNB, MultinomialNB
from sklearn.pipeline import Pipeline
from sklearn.svm import SVC

vectorizer = TfidfVectorizer(
    preprocessor=lambda x: map(str, x),
    tokenizer=lambda x: x,
    ngram_range=(1, 3))

model = Pipeline([('vectorizer', vectorizer), ('model', MultinomialNB())])
```

#### SVM
SVMs are a strong baseline for any text classification task. We can reuse the same vectorizer for this one.

```python
from sklearn.svm import SVC

model = Pipeline([('vectorizer', vectorizer), ('model', SVC())])
```

#### Multi Layer Perceptron
In other words - a vanilla feed forward neural network. This model doesn't use word embeddings, the input to the model is a bag of words.

```python
from keras.models import Sequential
from keras.layers import Dense, Dropout, Activation
from keras.preprocessing.text import Tokenizer

vocab_size = 20000
num_classes = 3

model = Sequential()
model.add(Dense(128, input_shape=(vocab_size,)))
model.add(Activation('relu'))
model.add(Dropout(0.2))
model.add(Dense(128, input_shape=(vocab_size,)))
model.add(Activation('relu'))
model.add(Dropout(0.2))
model.add(Dense(num_classes))
model.add(Activation('softmax'))

model.compile(loss='categorical_crossentropy',
              optimizer='adam',
              metrics=['accuracy'])
```

Inputs to this model need to be one-hot encoded, same goes for labels.

```python
import keras
from keras.preprocessing.text import Tokenizer

tokenizer = Tokenizer(num_words=vocab_size)
X = tokenizer.sequences_to_matrix(X, mode='binary')
y = keras.utils.to_categorical(y, num_classes)
```

#### (Bidirectional) LSTM
This is where things start to get interesting. The input to this model is not a bag of words but instead a sequence word ids. First thing to do is construct an embedding layer that will translate this sequence into a matrix of d-dimensional vectors.

```python

import numpy as np
from keras.layers import Embedding

max_seq_len = 100
embedding_dim = 37
# we will initialise the embedding layer with random values and set trainable=True
# we could also initialise with GloVe and set trainable=False
embedding_matrix = np.random.normal(size=(vocab_size, embedding_dim))
embedding_layer = Embedding(
    vocab_size,
    embedding_dim,
    weights=[embedding_matrix],
    input_length=max_seq_len,
    trainable=True)
```

Now for the model proper:

```python
from keras.layers import Dense, LSTM, Bidirectional
units = 64
sequence_input = Input(shape=(max_seq_len,), dtype='int32')

embedded_sequences = embedding_layer(sequence_input)
layer1 = LSTM(units,
    dropout=0.2,
    recurrent_dropout=0.2,
    return_sequences=True)
# for bidirectional LSTM do:
# layer = Bidirectional(layer)
x = layer1(embedded_sequences)
layer2 = LSTM(units,
    dropout=0.2,
    recurrent_dropout=0.2,
    return_sequences=False)  # last of LSTM layers must have return_sequences=False
x = layer2(x)
final_layer = Dense(class_count, activation='softmax')
predictions = final_layer(x)
model = Model(sequence_input, predictions)
```

This and all the other models using embeddings requires that labels are one-hot encoded and word id sequences are padded to fixed length with zeros:

```python
from keras.preprocessing.sequence import pad_sequences
from keras.utils import to_categorical

X = pad_sequences(X, max_seq_len)
y = to_categorical(y, num_classes=class_count)
```

#### François Chollet's CNN
This is the (slightly modified) architecture from [Keras tutorial](https://blog.keras.io/using-pre-trained-word-embeddings-in-a-keras-model.html). It's specifically designed for texts of length 1000, so I only used it for document classification, not for sentence classification.

```python
from keras.layers import Conv1D, MaxPooling1D

units = 35
dropout_rate = 0.2

x = Conv1D(units, 5, activation='relu')(embedded_sequences)
x = MaxPooling1D(5)(x)
x = Dropout(dropout_rate)(x)
x = Conv1D(units, 5, activation='relu')(x)
x = MaxPooling1D(5)(x)
x = Dropout(dropout_rate)(x)
x = Conv1D(units, 5, activation='relu')(x)
x = MaxPooling1D(35)(x)
x = Dropout(dropout_rate)(x)
x = Flatten()(x)
x = Dense(units, activation='relu')(x)
preds = Dense(class_count, activation='softmax')(x)
model = Model(sequence_input, predictions)
```

#### Yoon Kim's CNN 
This is the architecture from the [Yoon Kim's paper](https://arxiv.org/abs/1408.5882v2.pdf), my implementation is based on [Alexander Rakhlin's](https://github.com/alexander-rakhlin/CNN-for-Sentence-Classification-in-Keras). This one doesn't rely on text being exactly 1000 words long and is better suited for sentences.

```python

from keras.layers import Conv1D, MaxPooling1D, Concatenate

z = Dropout(0.2)(embedded_sequences)
num_filters = 8
filter_sizes=(3, 8),
conv_blocks = []
for sz in filter_sizes:
    conv = Conv1D(
        filters=num_filters,
        kernel_size=sz,
        padding="valid",
        activation="relu",
        strides=1)(z)
    conv = MaxPooling1D(pool_size=2)(conv)
    conv = Flatten()(conv)
    conv_blocks.append(conv)
z = Concatenate()(conv_blocks) if len(conv_blocks) > 1 else conv_blocks[0]

z = Dropout(0.2)(z)
z = Dense(units, activation="relu")(z)
predictions = Dense(class_count, activation="softmax")(z)
model = Model(sequence_input, predictions)
```

#### BLSTM2DCNN
Authors of the [paper](https://arxiv.org/abs/1611.06639v1) claim that combining BLSTM with CNN gives even better results than using either of them alone. Weirdly, unlike previous 2 models, this one uses 2D convolutions. This means that the receptive fields of neurons run not just across neighbouring words in the text but also across neighbouring coordinates in the embedding vector. This is suspicious because there is no relation between consecutive coordinates in e.g. GloVe embedding which they use. If one neuron learns a pattern involving coordinates 5 and 6, there is no reason to think that the same pattern will generalise to coordinates 22 and 23 - which makes convolution pointless. But what do I know.

```python
from keras.layers import Conv2D, MaxPool2D, Reshape

units = 128
conv_filters = 32
x = Dropout(0.2)(embedded_sequences)
x = Bidirectional(LSTM(
    units,
    dropout=0.2,
    recurrent_dropout=0.2,
    return_sequences=True))(x)
x = Reshape((2 * max_seq_len, units, 1))(x)
x = Conv2D(conv_filters, (3, 3))(x)
x = MaxPool2D(pool_size=(2, 2))(x)
x = Flatten()(x)
preds = Dense(class_count, activation='softmax')(x)
model = Model(sequence_input, predictions)
```

#### Stacking
In addition to all those base models, I implemented [stacking classifier](https://github.com/nadbordrozd/text-top-model/blob/master/ttm/stacking_classifier.py) to combine predictions of all those very different models. I used 2 versions of stacking. One where base models return probabilities, and those are combined by a simple logistic regression. The other, where base models return labels, and XGBoost is used to combine those.

### Datasets
For the document classification benchmark I used all the datasets from [here](http://www.cs.umb.edu/~smimarog/textmining/datasets/). This includes the 20 Newsgroups, Reuters-21578 and WebKB datasets in all their different versions (stemmed, lemmatised, etc.).

For the sentence classification benchmark I used the [movie review](http://www.cs.cornell.edu/people/pabo/movie-review-data/) polarity dataset and the [Stanford sentiment treebank](http://nlp.stanford.edu/~socherr/stanfordSentimentTreebank.zip) dataset.

### Results
Some models were only included in document classification or only in sentence classification - because they either performed terribly on the other or took too long to train. Hyperparameters of the neural models were (somewhat) tuned on one of the datasets before including them in the benchmark. The ratio of training to test examples was 0.7 : 0.3. This split was done 10 times on every dataset and each model was tested 10 time. The tables below show average accuracies across the 10 splits.

Without further ado:

#### Document classification benchmark
```text
model             r8-all-terms.txt    r52-all-terms.txt    20ng-all-terms.txt    webkb-stemmed.txt
--------------  ------------------  -------------------  --------------------  -------------------
MLP 1x360                    0.966                0.935                 0.924                0.930
SVM tfidf 2-gr               0.966                0.932                 0.920                0.911
SVM tfidf                    0.969                0.941                 0.912                0.906
MLP 2x180                    0.961                0.886                 0.914                0.927
MLP 3x512                    0.966                0.927                 0.875                0.915
CNN glove                    0.964                0.920                 0.840                0.892
SVM 2-gr                     0.953                0.910                 0.816                0.879
SVM                          0.955                0.917                 0.802                0.868
MNB                          0.933                0.848                 0.877                0.841
CNN 37d                      0.931                0.854                 0.764                0.879
MNB bi                       0.919                0.817                 0.850                0.823
MNB tfidf                    0.811                0.687                 0.843                0.779
MNB tfidf 2-gr               0.808                0.685                 0.861                0.763
BNB                          0.774                0.649                 0.705                0.741
BNB tfidf                    0.774                0.649                 0.705                0.741
```

{% img /images/text_top_model/doc_accuracy_stripplot.png %}

[Full results csv.](https://github.com/nadbordrozd/text-top-model/blob/master/ttm/document_results.csv)


#### Sentence classification benchmark
```text
model               subjectivity_10k.txt    polarity.txt
----------------  ----------------------  --------------
Stacker LogReg                     0.935           0.807
Stacker XGB                        0.932           0.793
MNB 2-gr                           0.921           0.782
MNB tfidf 2-gr                     0.917           0.785
MNB tfidf 3-gr                     0.916           0.781
MNB tfidf                          0.919           0.777
MNB                                0.918           0.772
LSTM GloVe                         0.921           0.765
BLSTM Glove                        0.917           0.766
SVM tfidf 2-gr                     0.911           0.772
MLP 1x360                          0.910           0.769
MLP 2x180                          0.907           0.766
MLP 3x512                          0.907           0.761
SVM tfidf                          0.905           0.763
BLSTM2DCNN GloVe                   0.894           0.746
CNN GloVe                          0.901           0.734
SVM                                0.887           0.743
LSTM 12D                           0.891           0.734
CNN 45D                            0.893           0.682
LSTM 24D                           0.869           0.703
BLSTM2dCNN 15D                     0.867           0.656
```
{% img /images/text_top_model/sent_accuracy_stripplot.png %}

[Full results csv.](https://github.com/nadbordrozd/text-top-model/blob/master/ttm/sentence_results.csv)




#### Conclusions
Well, this was underwhelming.

None of the fancy neural networks with embeddings managed to beat Naive Bayes and SVM, at least not consistently. A simple feed forward neural network with a single layer, did better than any other architecture.

I blame my hyperparameters. Didn't tune them enough. In particular, the number of epochs to train. It was determined once for each model, but different datasets and different splits probably require different settings.

And yet, the neural models are clearly doing something right because adding them to the ensemble and stacking significantly improves accuracy.

When I find out what exactly is the secret sauce that makes the neural models achieve the state of the art accuracies that papers claim they do, I will update my implementations and this post.
