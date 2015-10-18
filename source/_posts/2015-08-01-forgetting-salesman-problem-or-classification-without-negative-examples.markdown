---
layout: post
title: "Forgetful salesman problem or classification without negative examples"
date: 2015-08-01 20:49:26 +0100
comments: true
categories: 
---
How do you train a binary classifier when you have only positive-labeled training examples? 
Impossible? Maybe. But sometimes you can do something just as good. Let's start from the beginning...

### Lead generation
Everyone and their mum in the b2b sector is trying to use machine learning 
for lead generation. For our purposes lead-gen means selecting from the millions of active companies in your 
country the ones that are most likely to buy your product once contacted by your sales team. 
Needless to say lead generation is extremely _serious business_ and constitutes a market sector in its own right -
a type of b2b2b if you will.

One popular lead-gen strategy is to look for leads among companies similar the ones that have 
worked out for you in the past. A machine learning implementation of this strategy is straightforward:

1. collect data on all relevant companies 
2. take all the companies your sales have contacted in the past and label every one as 
  either successful (you made money) or failed (you wasted your time) lead. This is 
  you training set.
3. extract good features for every company\*
4. train a binary classifier (predicting successful/failed label) on your training set.
  Ideally this should be a classifier that outputs probabilities.
5. apply the classifier to all the companies outside the training set and hand the results over 
  to sales  
The number assigned by the classifier to a given company is (in theory at least) the probability 
that the lead will be successful. Highest scorers should be prioritized, low scorers should be
left alone. So far, so good.

### The problem 
An interesting difficulty frequently arises when you try to apply this approach in real life. 
Sales teams usually have good records on their clients but often fail to keep track of all the prospects
that didn't work out. As a result, you end up with only positive examples to train your classifier on. 
It's not possible in general to train a classifier on a training set with one class amputated this way. But...

### The solution
Keep in mind that:

  - in addition to the positive examples, you have also the full set of all data points (all companies
	whether previously contacted or not)
  - you are not interested in the absolute probability of success of a given lead per se. You only really need the
  relative ranking of different leads. All the classifier scores may be off by a factor of 10 but as long as 
  the order is preserved - you'll still be able to prioritize good leads over rubbish ones.
  
The problem solves itself when stated in mathematical terms. Consider a space of all possible companies $X$. 
We can view the set of actual companies as a sample from some probability distribution $P(x)$ defined for
$x \in X$. Every point in this 
 
$$
\begin{align}
\mbox{Union: } & A\cup B = \{x\mid x\in A \mbox{ or } x\in B\} \\
\mbox{Concatenation: } & A\circ B  = \{xy\mid x\in A \mbox{ and } y\in B\} \\
\mbox{Star: } & A^\star  = \{x_1x_2\ldots x_k \mid  k\geq 0 \mbox{ and each } x_i\in A\} \\
\end{align}
$$
   
   
  {% img /images/280.jpg %}
  
  \* this is arguably the hardest and most important step, but I'm glossing over it as it's not relevant to this 
  post