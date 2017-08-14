---
layout: post
title: "You won't believe how this Islington single dad is making £500/day while working from home"
date: 2017-06-20 22:32:10 +0100
comments: true
categories: 
---
<sup>Trigger warnings: programming humor, algorithms and data structures, Java</sup>

I'm interviewing data engineering contractors recently. All of the candidates are very senior people with 10+ years of experience. My go to question:

**Me:** _What data structure would you use (in your favorite programming language) to store a large number (let's say 100k) of strings - so they can be looked up efficiently? And by 'looked up' I mean - user will come up with a new string ('banana') and you have to quickly tell if this string is an element of your collection of 100k?_  
**Candidate:** I would load them in an RDD and then...  
**Me:** _No, no, I'm not asking about Spark. This is a regular single-threaded, in-memory, computer science 101 problem. What is the simplest thing that you could do?_  
**Candidate:** Grep. I would use grep to look for the string.  
**Me:** _Terrific. Sorry, maybe I wasn't clear, I'm NOT talking about finding a substring in a larger text... You know what, forget about the strings. There are no strings. You have 100k integers. What data structure would you put them in so you can quickly look up if a new integer (1743) belongs to the collection?_  
**Candidate:** For integers I would use an array.  
**Me:** _And how do you find out if the new integer belongs to this array?_  
**Candidate:** There is a method 'contains'.  
**Me:** _Ok. And for an array of n integers, what is the expected running time of this method in terms of n?_  
**Candidate:** ...  
**Me:** ...  
**Candidate:** I think it would be under one minute.  
**Me:** _Indeed._  

This one was particularly funny, but otherwise unexceptional. This week I interviewed 4 people and not a single one of them mentioned hash tables. I would have also accepted 'HashMap', 'Map', 'Set', 'dictionary', 'python curly braces' - anything pointing in vaguely the right direction, even if they didn't understand the implementation. Instead I only got 'a vector, because they are thread safe', 'ArrayList because they are extensible', 'a List because lists in scala are something something', 'in my company we always use Sequences'. Again: these are very experienced people who are being paid a lot of money contracting for corporations in London and who can very convincingly bullshit about their Kafkas, Sparks, HBases and all the other Big Data nonsense.

Another bizarre conversation occurred when a candidate with 16 years of experience with Java (confirmed by the Sun certificate) immediately came up with the idea of putting the strings in buckets based on their hash and started explaining to me basically how to implement a hash table in Java, complete with the discussion of the merits of different string hashing functions. When I suggested that maybe Java already has a collection type that does all of this he reacted with indignation - he shouldn't have to know this, you can find out on the internet. Fair enough, but one would think that after 16 years of programming in that language someone would have encountered HashMaps once or twice... This seemed odd enough that for my next question I went off script:

**Me:** _Can you tell me what is the signature of the main method in Java?_  
**Candidate:** What?  
**Me:** _Signature of the main method. Like, if you're writing the 'hello world' program in Java, what would you have to type?_  
**Candidate:** class HelloWorld  
**Me:** _Go on._  
**Candidate:** int main() or void main() I think  
**Me:** _And the parameters?_  
**Candidate:** Yes, I remember, there are command line parameters.  
**Me:** ...  
**Candidate:** Two parameters and the second is an integer.  
**Me:** _Thank you, I know all I wanted to know._  

Moral of this story?

Come to London, be a data engineering contractor and make £500/day. You can read about Java on wikipedia, put 15 years of experience on your resume and no one will be the wiser.