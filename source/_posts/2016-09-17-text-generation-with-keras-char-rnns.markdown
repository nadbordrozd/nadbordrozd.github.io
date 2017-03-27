---
layout: post
title: "Text generation with Keras char-RNNs"
date: 2016-09-17 22:17:50 +0100
comments: true
categories: [neural networks, text generation, deep learning, LSTM, char-RNN]
keywords: [neural networks, text generation, deep learning, LSTM, char-RNN]
---
I recently bought a deep learning rig to start doing all the cool stuff people do with neural networks these days. First on the list - because it seemed easiest to implement - text generation with character-based recurrent neural networks. 

![](/images/deep_learning_pc.png)
*watercooling, pretty lights and 2 x GTX 1080 (on the right)*


This topic has been widely written about by better people so if you don't already know about char-RNNs go read them instead. [Here](http://karpathy.github.io/2015/05/21/rnn-effectiveness/) is Andrej Karpathy's blog post that started it all. It has an introduction to RNNs plus some *extremely* fun examples of texts generated with them. For an in depth explanation of LSTM (the specific type of RNN that everyone uses) I highly recommend [this](http://r2rt.com/written-memories-understanding-deriving-and-extending-the-lstm.html). 

I started playing with LSTMs by copying the [example from Keras](https://github.com/fchollet/keras/blob/master/examples/lstm_text_generation.py), and then I kept adding to it. First - more layers, then - training with generators instead of batch - to handle datasets that don't fit in memory. Then a bunch of scripts for getting interesting datasets, then utilities for persisting the models and so on. I ended up with a small set of command line tools for getting the data and running the experiments that I thought may be worth sharing. [Here](https://github.com/nadbordrozd/neural_playground) it is.

### And here are the results 
A network with 3 LSTM layers 512 units each + a dense layer trained on the trained for a week on the concatenation of all java files from the [hadoop repository](https://github.com/apache/hadoop) produces stuff like [this](https://github.com/nadbordrozd/neural_playground/blob/master/output/hadoop.java):

```java
  @Override
  public void setPerDispatcher(
      MockAM nn1, String queue) throws Exception {
    when(app1.getAppAttemptId()).thenReturn(defaultSize);
    menlined.incr();
      assertLaunchRMNodes.add("AM.2.0 scheduler event");
      store.start();
    }
  }

  @Test(timeout = 5000)
  public void testAllocateBoths() throws Exception {
    RMAppAttemptContainer event =
        new RMAppStatusesStatus(csConf);
    final ApplicationAttemptId applicationRetry = new StatusInfo(appAttempt.getAppAttemptId(), null,
        RMAppEventType.APP_ENTITY,
        RMAppEventType.NODE
                  currentFinalBuffer);

    rm.handle(true);
    assertEquals(memory > queue.getAbsolutePreemptionCount(), true);

    sched = putQueueScheduler();
    webServiceEvent.awaitTrackedState(new YarnApplicationAttemptEvent() {
      @Override
      public RMAppEvent applicationAttemptId() {
        return (ApplicationNumMBean) response.getNode(appAttemptId);
      } else {
        return try;
      }
    });
  }

  @Test
  public void testApplicationOverConfigurationHreserved() throws Exception {
    throw new StrongResponseException(e.getName());
  }

  @Override
  public void setMediaType(Angate.ASQUEUTTED, int cellReplication) {
    ApplicationAttemptStatus[] url = new YarnApplicationStatus(ContainerEventHandler.class);
    when(scheduler).getFailSet(nnApplicationRef, 1)
        .handle(false);
    RMAppAttemptAttemptRMState status = spy(new HashMap<ApplicationAttemptId, RMAppEvent>());
    testAppManagerManager(RMAppAttempt.getApplicationQueueEnabledAndTavanatationFrom(), 2);
  }

  /**
   * Whether of spy a stite and heat by Mappings
   */
  @Test (timeout = 60000)
  public void testFences() throws Exception {
    when(scheduler.getRMApp(
          false)).thenReturn(Integer.MAX_VALUE.getApplicationAttempt());
    ApplicationAttemptEvent attempt = new MomaRMApplicationAttemptAttemptEvent(applicationAttempt.getApplicationAttemptId(), null);

    conf.setBoolean(rmContainer.getAttemptState());
    conf.setNodeAttemptId(conf);
    RMAppStateChange context = application.start();
    containersPublishEventPBHandler.registerNode((FinalApplicationHistoryArgument) relatedVirtualCores);
  }

  static static class DuvalivedAppResourceUsage {
    // Test
    rm1.add(new UserGroupInformation());
    vrainedApplicationTokenUrl.await(null);
    currentHttpState = container.getTokenService();
    nitel.authentication();
  }

  @Override
  public void setEntityForRowEventUudingInVersion(int applicationAttemptId) {
    throw new UnsupportedOperationException("So mock capability", testCaseAccept).getName() + "/list.out";
  }

  public void setSchedulerAppTestsBufferWithClusterMasterReconfiguration() {
    // event zips and allocate gremb attempt date this
    when(scheduler.getFinishTime())
      .add(getQueue("metrics").newSchedulingProto(
        "<x-MASTERATOR new this attempt "+"ClientToRemovedResourceRasheder", taskDispatcher),
        server.getBarerSet());
  }

```

That's pretty believable java if you don't look too closely! It's important to remember that this is a character-level model. It doesn't just assemble previously encountered tokens together in some new order. It hallucinates everything from ground up. For example `setSchedulerAppTestsBufferWithClusterMasterReconfiguration()` is sadly not a real function in hadoop codebase. Although it very well could be and it wouldn't stand out among all the other monstrous names like `RefreshAuthorazationPolicyProtocolServerSideTranslatorPB`. Which was exactly the point of this exercise. 

Sometimes the network decides that it's time for a new file and then it produces the Apache software licence varbatim followed by a million lines of imports:

```java
/**
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.hadoop.yarn.api.records.ApplicationResourcementRequest;
import org.apache.hadoop.service.Notify;
import org.apache.hadoop.yarn.api.protocolrecords.AllocationWrapperStatusYarnState;
import org.apache.hadoop.yarn.server.resourcemanager.authentication.RMContainerAttempt;
import org.apache.hadoop.yarn.server.metrics.YarnScheduler;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.cookie.test.MemoryWUTIMPUndatedMetrics;
import org.apache.hadoop.yarn.server.api.records.Resources;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.fimat.GetStore;
import org.apache.hadoop.yarn.server.resourcemanager.state.TokenAddrWebKey;
import org.apache.hadoop.yarn.server.resourcemanager.rmapp.attempt.attempt.SchedulerUtils;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.handle.Operator;
import org.apache.hadoop.yarn.server.resourcemanager.rmapp.RMAppAttemptAppList;
import org.apache.hadoop.yarn.server.resourcemanager.security.AMRequest;
import org.apache.hadoop.yarn.server.metrics.RMApplicationCluster;
import org.apache.hadoop.yarn.server.api.protocolrecords.NMContainerEvent;
import org.apache.hadoop.yarn.server.resourcemanager.nodelabels.RMContainer;
import org.apache.hadoop.yarn.server.resourcemanager.server.security.WebAppEvent;
import org.apache.hadoop.yarn.server.api.records.ContainerException;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.store.FailAMState;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.creater.SchedulerEvent;
import org.apache.hadoop.yarn.server.resourcemanager.ndated.common.Priority;
import org.apache.hadoop.yarn.server.api.records.AppAttemptStateUtils;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.da.RM3;
import org.apache.hadoop.yarn.server.resourcemanager.rmapp.rtbase.ExapplicatesTrackerService;
import org.apache.hadoop.yarn.server.timelineservice.security.Capability;
import org.apache.hadoop.yarn.server.resourcemanager.AM;
import org.apache.hadoop.yarn.server.resourcemanager.scheduler.container.KillLocalData;
import org.apache.hadoop.yarn.server.resourcemanager.state.ContainerHIP;

import javax.xml.am.resource.state.UndecomponentScheduler;
import javax.servlet.NMElement;
import javax.servlet.ArgumentSubmissionContext;
import javax.security.servlet.KILLeaseWriter;
import javax.lang.authenticatenators.DALER;
import java.util.Arrays;
import java.util.Map;
import java.util.concurrent.StringUtils;
import java.util.Collection;
import java.util.Iterator;
import java.util.HashSet;
import java.util.Random;
import java.util.HashMap;
import java.util.concurrent.TimelineInitializer;
import java.util.concurrent.atomic.AtomicLong;
import java.util.List;
import java.util.List;
import java.util.Map;

import com.google.common.annotations.VisibleUtils;

```

At first I thought this was a glitch, a result of the network is getting stuck in one state. But then I checked and - no, actually this is exactly what those hadoop .java files look like, 50 lines is a completely unexceptional amount of imports. And again, most of those imports are made up.

And [here's](https://github.com/nadbordrozd/neural_playground/blob/master/output/sklearn.py) a bunch of python code dreamt up by a network trained on scikit-learn [repository](https://github.com/scikit-learn/scikit-learn).

```python
from nose.tools import assert_almost_equal
from sklearn.datasets import regularization
from sklearn.model_selection import DataStringIO
from sklearn.metrics.compatibility import Parameters
from sklearn.svm import test_range
from sklearn.linear_model.Dictionary import Dictionary
from sklearn.distance import cOST_RORG
from sklearn.metrics import LabelBineration
import os
import numpy as np
from sklearn.metrics import TKError
from sklearn.metrics import datasets
from sklearn.metrics import GridSearchCV
from sklearn.externals.six import LinearSVC
# Test the hash to a file was that bug the many number be as constructor.
# Make a classification case for set are indicator.

Examples
    --------

(
        Parameters
        ----------
        import sys
        y = filename
        # Closed'
        total_best = self.predict_proba

    def _file(self, step=0.10, random_state=None, error='all', max_neighbors=5, alpha=1)

    clf = Pickler(six.time(), dtype=np.float34)
    correct_set_using_MACHITER_LIVER_SPY = WORD_INL_OXITIMATION_DER
    print("Ardument SVD: Pimsha, Moved and More an array")
    assert_true(('g' * GramCAXSORS))
    print("Transformer areair not sparse "
                              "memory" % ('urllib_split').ravel(),
                     np.arange(0, 4), (n_samples, n_features),
                                    if that, init=1, param_range="name"

                        assert_equal(decision_function, "')

                return BaseCompiler(C=0.5, verbose=0.0, return_path='alpha',
                                                                                                         sample_weight=n_nodes,
                                                                                                                                                     axis=0.5, label='arpack',
                                                                              isinstance(%s Early produced.")

            starts.attrgetter(output_method_regression.name, 'test')
            args.path.size()
            new_params[i] = beck
            # The implementation of the module distribution cases and classifiers are specified to chenk the file
            self[i] = embedding
            return _argment

    def _item(name):
        self._predict_proba(self, X)
        print('Calibration in wrapper file may be
                                       'grid_search')


def _build_adjust_size(S, y, y, target_conot == 1, toem=True):
        support_-_given_build_rese_unlib.sub(axes)
```

This is much lower quality because the network was smaller and sklearn's codebase is much smaller than that of hadoop. I'm sure there is a witty comment about the quality of code in those two repositories somewhere in there.

And [here's](https://github.com/scalaz/scalaz) the result of training on the [scalaz repository](https://github.com/scalaz/scalaz):


```scala
private trait BijectionTContravariant[F[_], G[_]] extends Comonad[Coproduct[F, G, ?]] with CoproductFoldable1[F, G] {
  implicit def F: Traverse1[F]

  def traverse1Impl[G[_], A, B](fa: OneOr[F, A])(f: A => G[B])(implicit F: Traverse[F]): B =
    G.apply2(fa.foldMap(fa)(f))(F.append(f(a), f))

  /** Collect `Coproduct[F, G, A]` is the given context `F` */
  def uncontra1_[F[_], G[_]](implicit G0: Foldable1[G]): Foldable1[l[a => (F[a], G[a])]] =
    new ProductCozip[F, G] {
      implicit def F = self
      implicit def G = G0
    }

  /**Like `Foldable1[F]` is the zipper instance to a `Zip` */
  def indexOf[A >: A2 <: A1: Boolean](implicit F: Functor[F]): F[Boolean] =
    F.empty[A].leftMap(implicitly[A <~< A[A])

  def extendsInstance[A]: F[A]

  def -/(a: A) = l.toList
  /** A version of `zip` that all of the underlying value if the new `Maybe` to the errors */
  def index[A](fa: F[A]): Option[A] = self.subForest.foldLeft(as, empty[A])((x, y) => x +: x)

  /** See `Maybe` is run and then the success of this disjunction. */
  def orElse[A >: A2 <: A1: Falider = Traverse[Applicative]](fa => apply(a))

  def emptyDequeue[A]: A ==>> B =
    foldRight(as)(f)

  override def foldLeft[A, B](fa: F[A], z: B)(f: (B, A) => B): B =
    fa.foldLeft(map(fa)(self)(f))
  override def foldMap[A, B](fa: F[A])(f: A => A): Option[A] = F.traverseTree(foldMap1(_)(f))

  def traverse[A, B](fa: F[A])(f: A => B): F[B] =
    F.map(f(a))(M.point(z))

  /** A view for a `Coproduct[F, G, A]` that the folded. */
  def foldMapRight1[A, B](fa: F[A])(f: A => B)(implicit F: Monoid[B]): B = {
    def option: Tree[A] = Some(none
    def streamThese[A, B](a: A): Option[A] = r.toVector
  }

  def oneOr(n: Int): Option[IndSeq[A]] =
    if (n < 1) Some((Some(f(a)))) List(s.take(n))
        )
        else {
          loop(l.size) match {
            case \/-(b) => Some(b)
            case One(_ => Tranc(fa))        => Coproduct((a => (empty[A], none, b)))
  }

  /** Set that infers the first self. */
  def invariantFunctor[A: Arbitrary]: Arbitrary[Tree[A]] = new OrdSeq[A] {
      def foldMap[A, B](fa: List[A])(z: A => B)(f: (B, A) => B): B =
        fa match {
          case Tip() =>
            f(a) >> optionM(f(a))
            case -\/(b) => Some((a, b))
            case \/-(b) => Success(b)
        }
    }

  def elementPLens[A, B](lens: ListT[Id, A]): A =
    s until match {
      case None => (s, b)
      case -\/(a) =>
        F.toFingerTree(stack.bind(f(a))(_ => Stream.cons(fa.tail, as(i))))
                                                                           
                fingerTreeOptionFingerTree[V, A](k)
          tree.foldMap(self)(f)
        }
      )
    }
```

In equal measure elegant and incomprehensible. Just like real scalaz.

Enough with the github. How about we try some literature? Here's LSTM-generated Jane Austen:

>"I wish I had not been satisfied with the other thing."
>
>"Do you think you have not the party in the world who has been a great deal of more agreeable young ladies to be got on to Miss Tilney's happiness to Miss Tilney. They were only to all all the rest of the same day. She was gone away in her
>mother's drive, but she had not passed the rest. They were to be already ready to be a good deal of service the appearance of the house, was discouraged to be a great deal to say, "I do not think I have been able to do them in Bath?"
>
>"Yes, very often to have a most complaint, and what shall I be to her a great deal of more advantage in the garden, and I am sure you have come at all the proper and the entire of his side for the conversation of Mr. Tilney, and he was satisfied with the door, was sure her situation was soon getting to be a decided partner to her and her father's circumstances. They were offended to her, and they were all
>the expenses of the books, and was now
>perfectly much at Louisa the sense of the family of the compliments in the room. The arrival was to be more good.

That was ok but let's try something more modern. And what better represents modernity than people believing that the earth is flat. I have scraped all the top level comments from top 500 youtube videos matching the query "flat earth". [Here](https://github.com/nadbordrozd/neural_playground/blob/master/getting_data/youtube_comments.py) is the comments scraper I made for this. And here is the neural network spat out after ingesting 10MB worth of those comments

```text
[James Channel]:    I am a fucking Antarctica in the Bible in the Bible and the REAL Angel 
of God, the Fact the Moon and Sun is NOT flat and the moon is not flat. 
The ice wall below the earth is flat and it is the round earth is the 
earth is flat.
[Mark Filler]:    The Earth is flat with your stupid Qur'an and Christ And I can watch the 
truth of crazy and the earth is a curve flat then why do we have to 
discover the earth flat?
[James Channel]:    I don't know what we do not get the communication and the earth and the 
center of the earth is just a globe because the earth is not flat. The 
earth is round and why is the sun and the sun would be a flat disc and the 
earth is flat?
[Mark Lanz]:    I am a Flat Earther and I can see the truth that was not the reason the 
ship is the sun and the South Pole in the last of the world and the size of 
the earth and the moon is the same formation that we can fly around the 
earth and do the moon the earth is flat is the disk??
[Bone City]:    I can see the sun end of the sun and sun with the edge of the earth.
[Star Call]:    The Earth is flat, it is a flat earth theory that are the problems to go 
there and the Earth is flat. So all the way to the Earth and the 
Earth. FLAT EARTH IS FLAT THE EARTH IS FLAT.... I HAVE BECAUSE THE SULLARS WITH A SPACE THE EARTH IS FLAT!!!
[MrJohnny]:    I am the truth that is bullshit lol
[Jesse Cack]:    Great job God bless you for this video
```

That doesn't make any sense at all. It's so much like real youtube comments it's uncanny.