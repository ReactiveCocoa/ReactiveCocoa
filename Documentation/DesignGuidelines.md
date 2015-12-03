# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

This document assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][1] is a better
resource for getting up to speed on the main types and concepts provided by RAC.

**[The `Event` contract][2]**

 1. [`Next`s provide values or indicate the occurrence of events][3]
 1. [Failures behave like exceptions and propagate immediately][4]
 1. [Completion indicates success][5]
 1. [Interruption cancels outstanding work and usually propagates immediately][6]
 1. [Events are serial][7]
 1. [Events cannot be sent recursively][8]
 1. [Events are sent synchronously by default][9]

**[The `Signal` contract][10]**

 1. [Signals start work when instantiated][11]
 1. [The event stream of the signal is alive until the underlying observer is released][12]
 1. [Unreachable signals with no observer would be terminated without an event][13]
 1. [Observing a signal does not have side effects unless the signal is unreachable][14]
 1. [All observers of a signal see the same events in the same order][15]
 1. [Terminating events dispose of signal resources][16]

**[The `SignalProducer` contract][17]**

 1. [Signal producers start work on demand by creating signals][18]
 1. [Each produced signal may send different events at different times][19]
 1. [Signal operators can be lifted to apply to signal producers][20]
 1. [Disposing of a produced signal will interrupt it][21]

**[Best practices][22]**

 1. [Process only as many values as needed][23]
 1. [Observe events on a known scheduler][24]
 1. [Switch schedulers in as few places as possible][25]
 1. [Capture side effects within signal producers][26]
 1. [Share the side effects of a signal producer by sharing one produced signal][27]
 1. [Prefer managing lifetime with operators over explicit disposal][28]

**[Implementing new operators][29]**

 1. [Prefer writing operators that apply to both signals and producers][30]
 1. [Compose existing operators when possible][31]
 1. [Forward failure and interruption events as soon as possible][32]
 1. [Switch over `Event` values][33]
 1. [Avoid introducing concurrency][34]
 1. [Avoid blocking in operators][35]

## The `Event` contract

[Events][36] are fundamental to ReactiveCocoa. [Signals][37] and [signal producers][38] both send
events, and may be collectively called “event streams.”

Event streams must conform to the following grammar:

\`\`\`
Next\* (Interrupted | Failed | Completed)?
\`\`\`

This states that an event stream consists of:

 1. Any number of `Next` events
 1. Optionally followed by one terminating event, which is any of `Interrupted`, `Failed`, or `Completed`

After a terminating event, no other events will be received.

#### `Next`s provide values or indicate the occurrence of events

`Next` events contain a payload known as the “value.” Only `Next` events are
said to have a value. Since an event stream can contain any number of `Next`s,
there are few restrictions on what those values can mean or be used for, except
that they must be of the same type.

As an example, the value might represent an element from a collection, or
a progress update about some long-running operation. The value of a `Next` event
might even represent nothing at all—for example, it’s common to use a value type
of `()` to indicate that something happened, without being more specific about
what that something was.

Most of the event stream [operators][39] act upon `Next` events, as they represent the
“meaningful data” of a signal or producer.

#### Failures behave like exceptions and propagate immediately

`Failed` events indicate that something went wrong, and contain a concrete error
that indicates what happened. Failures are fatal, and propagate as quickly as
possible to the consumer for handling.

Failures also behave like exceptions, in that they “skip” operators, terminating
them along the way. In other words, most [operators][40] immediately stop doing
work when a failure is received, and then propagate the failure onward. This even applies to time-shifted operators, like [`delay`][41]—which, despite its name, will forward any failures immediately.

Consequently, failures should only be used to represent “abnormal” termination. If it is important to let operators (or consumers) finish their work, a `Next`
event describing the result might be more appropriate.

If an event stream can _never_ fail, it should be parameterized with the
special [`NoError`][42] type, which statically guarantees that a `Failed`
event cannot be sent upon the stream.

#### Completion indicates success

An event stream sends `Completed` when the operation has completed successfully,
or to indicate that the stream has terminated normally.

Many operators manipulate the `Completed` event to shorten or extend the
lifetime of an event stream.

For example, [`take`][43] will complete after the specified number of values have
been received, thereby terminating the stream early. On the other hand, most
operators that accept multiple signals or producers will wait until _all_ of
them have completed before forwarding a `Completed` event, since a successful
outcome will usually depend on all the inputs.

#### Interruption cancels outstanding work and usually propagates immediately

An `Interrupted` event is sent when an event stream should cancel processing.
Interruption is somewhere between [success][44]
and [failure][45]—the
operation was not successful, because it did not get to finish, but it didn’t
necessarily “fail” either.

Most [operators][46] will propagate interruption immediately, but there are some
exceptions. For example, the [flattening operators][47] will ignore
`Interrupted` events that occur on the _inner_ producers, since the cancellation
of an inner operation should not necessarily cancel the larger unit of work.

RAC will automatically send an `Interrupted` event upon [disposal][48], but it can
also be sent manually if necessary. Additionally, [custom
operators](#implementing-new-operators) must make sure to forward interruption
events to the observer.

#### Events are serial

RAC guarantees that all events upon a stream will arrive serially. In other
words, it’s impossible for the observer of a signal or producer to receive
multiple `Event`s concurrently, even if the events are sent on multiple threads
simultaneously.

This simplifies [operator][49] implementations and [observers][50].

#### Events cannot be sent recursively

Just like RAC guarantees that [events will not be received
concurrently](#events-are-serial), it also guarantees that they won’t be
received recursively. As a consequence, [operators][51] and [observers][52] _do not_ need to
be reentrant.

If an event is sent upon a signal from a thread that is _already processing_
a previous event from that signal, deadlock will result. This is because
recursive signals are usually programmer error, and the determinacy of
a deadlock is preferable to nondeterministic race conditions.

When a recursive signal is explicitly desired, the recursive event should be
time-shifted, with an operator like [`delay`][53], to ensure that it isn’t sent from
an already-running event handler.

#### Events are sent synchronously by default

RAC does not implicitly introduce concurrency or asynchrony. [Operators][54] that
accept a [scheduler][55] may, but they must be explicitly invoked by the consumer of
the framework.

A “vanilla” signal or producer will send all of its events synchronously by
default, meaning that the [observer][56] will be synchronously invoked for each event
as it is sent, and that the underlying work will not resume until the event
handler finishes.

This is similar to how `NSNotificationCenter` or `UIControl` events are
distributed.

## The `Signal` contract

A [signal][57] is an “always on” stream that obeys [the `Event`
contract](#the-event-contract).

`Signal` is a reference type, because each signal has identity—in other words, each
signal has its own lifetime, and may eventually terminate. Once terminated,
a signal cannot be restarted.

#### Signals start work when instantiated

[`Signal.init`][58] immediately executes the generator closure that is passed to it.
This means that side effects may occur even before the initializer returns.

It is also possible to send [events][59] before the initializer returns. However,
since it is impossible for any [observers][60] to be attached at this point, any
events sent this way cannot be received.

#### The event stream of the signal is alive until the underlying observer is released

A `Signal` instance is only a proxy for attaching observers to the underlying event stream. Therefore, even if the caller does not maintain a reference to the `Signal`:

 - The event stream created with [`Signal.init`][61] is kept alive until the [observer][62] argument passed into the generator closure is released.
 - The event stream created with [`Signal.pipe`][63] is kept alive until the returned observer
   is released.

This ensures that signals associated with long-running work do not deallocate
prematurely.

#### Unreachable signals with no observer would be terminated without an event

A `Signal` instance is not retained internally, but only the necessary data structures for the underlying event stream. Therefore, it is possible of the `Signal` to be deallocated ahead of the termination of the underlying event stream.

A signal is defined as an **unreachable** signal if the respective `Signal` instance is deallocated. An unreachable signal is guaranteed to have no future [observer][64] being attached to, but it can still have existing [observers][65] and side effects on-going.

If an unreachable signal has no remaining observer, the event stream and the associated side effects should be terminated immediately without an event, and dispose all the resources being used.

#### Observing a signal does not have side effects unless the signal is unreachable.

The work associated with a `Signal` does not start or stop when [observers][66] are
added or removed if the `Signal` is reachable, so the [`observe`][67] method never
has side effects.

A signal’s side effects can only be stopped through [a terminating
event](#signals-are-retained-until-a-terminating-event-occurs), or by becoming an [unreachable signal][13] with all observers detached.

#### All observers of a signal see the same events in the same order

Because [observation does not have side
effects](#observing-a-signal-does-not-have-side-effects-unless-the-signal-is-unreachable), a `Signal` never
customizes events for different [observers][68]. When an event is sent upon a signal,
it will be [synchronously][69]
distributed to all observers that are attached at that time, much like
how `NSNotificationCenter` sends notifications.

In other words, there are not different event “timelines” per observer. All
observers effectively see the same stream of events.

There is one exception to this rule: adding an observer to a signal _after_ it
has already terminated will result in exactly one
[`Interrupted`][70]
event sent to that specific observer.

#### Terminating events dispose of signal resources

When a terminating [event][71] is sent along a `Signal`, all [observers][72] will be
released, and any resources being used to generate events should be disposed of.

The easiest way to ensure proper resource cleanup is to return a [disposable][73]
from the generator closure, which will be disposed of when termination occurs.
The disposable should be responsible for releasing memory, closing file handles,
canceling network requests, or anything else that may have been associated with
the work being performed.

## The `SignalProducer` contract

A [signal producer][74] is like a “recipe” for creating
[signals][75]. Signal producers do not do anything by themselves—[work begins only
when a signal is produced](#signal-producers-start-work-on-demand-by-creating-signals).

Since a signal producer is just a declaration of _how_ to create signals, it is
a value type, and has no memory management to speak of.

#### Signal producers start work on demand by creating signals

The [`start`][76] and [`startWithSignal`][77] methods each
produce a `Signal` (implicitly and explicitly, respectively). After
instantiating the signal, the closure that was passed to
[`SignalProducer.init`][78] will be executed, to start the flow
of [events][79] after any observers have been attached.

Although the producer itself is not _really_ responsible for the execution of
work, it’s common to speak of “starting” and “canceling” a producer. These terms
refer to producing a `Signal` that will start work, and [disposing of that
signal](#disposing-of-a-produced-signal-will-interrupt-it) to stop work.

A producer can be started any number of times (including zero), and the work
associated with it will execute exactly that many times as well.

#### Each produced signal may send different events at different times

Because signal producers [start work on
demand](#signal-producers-start-work-on-demand-by-creating-signals), there may
be different [observers][80] associated with each execution, and those observers
may see completely different [event][81] timelines.

In other words, events are generated from scratch for each time the producer is
started, and can be completely different (or in a completely different order)
from other times the producer is started.

Nonetheless, each execution of a signal producer will follow [the `Event`
contract](#the-event-contract).

#### Signal operators can be lifted to apply to signal producers

Due to the relationship between signals and signal producers, it is possible to
automatically promote any [operators][82] over one or more `Signal`s to apply to
the same number of `SignalProducer`s instead, using the [`lift`][83] method.

`lift` will apply the behavior of the specified operator to each `Signal` that
is [created when the signal produced is started][84].

#### Disposing of a produced signal will interrupt it

When a producer is started using the [`start`][85] or
[`startWithSignal`][86] methods, a [`Disposable`][87] is
automatically created and passed back.

Disposing of this object will
[interrupt][88]
the produced `Signal`, thereby canceling outstanding work and sending an
`Interrupted` [event][89] to all [observers][90], and will also dispose of
everything added to the [`CompositeDisposable`][91] in
[SignalProducer.init][92].

Note that disposing of one produced `Signal` will not affect other signals created
by the same `SignalProducer`.

## Best practices

The following recommendations are intended to help keep RAC-based code
predictable, understandable, and performant.

They are, however, only guidelines. Use best judgement when determining whether
to apply the recommendations here to a given piece of code.

#### Process only as many values as needed

Keeping an event stream alive longer than necessary can waste CPU and memory, as
unnecessary work is performed for results that will never be used.

If only a certain number of values or certain number of time is required from
a [signal][93] or [producer][94], operators like
[`take`][95] or [`takeUntil`][96] can be used to
automatically complete the stream once a certain condition is fulfilled.

The benefit is exponential, too, as this will terminate dependent operators
sooner, potentially saving a significant amount of work.

#### Observe events on a known scheduler

When receiving a [signal][97] or [producer][98] from unknown
code, it can be difficult to know which thread [events][99] will arrive upon. Although
events are [guaranteed to be serial][100], sometimes stronger
guarantees are needed, like when performing UI updates (which must occur on the
main thread).

Whenever such a guarantee is important, the [`observeOn`][101]
[operator][102] should be used to force events to be received upon
a specific [scheduler][103].

#### Switch schedulers in as few places as possible

Notwithstanding the [above][104], [events][105]
should only be delivered to a specific [scheduler][106] when absolutely
necessary. Switching schedulers can introduce unnecessary delays and cause an
increase in CPU load.

Generally, [`observeOn`][107] should only be used right before observing
the [signal][108], starting the [producer][109], or binding to
a [property][110]. This ensures that events arrive on the expected
scheduler, without introducing multiple thread hops before their arrival.

#### Capture side effects within signal producers

Because [signal producers start work on
demand](#signal-producers-start-work-on-demand-by-creating-signals), any
functions or methods that return a [signal producer][111] should
make sure that side effects are captured _within_ the producer itself, instead
of being part of the function or method call.

For example, a function like this:

\`\`\`swift
func search(text: String) -\> SignalProducer\<Result, NetworkError\>
\`\`\`

… should _not_ immediately start a search.

Instead, the returned producer should execute the search once for every time
that it is started. This also means that if the producer is never started,
a search will never have to be performed either.

#### Share the side effects of a signal producer by sharing one produced signal

If multiple [observers][112] are interested in the results of a [signal
producer][Signal Producers][113], calling [`start`][114] once for each observer
means that the work associated with the producer will [execute that many
times](#signal-producers-start-work-on-demand-by-creating-signals) and [may not
generate the same results](#each-produced-signal-may-send-different-events-at-different-times).

If:

 1. the observers need to receive the exact same results
 1. the observers know about each other, or
 1. the code starting the producer knows about each observer

… it may be more appropriate to start the producer _just once_, and share the
results of that one [signal][115] to all observers, by attaching them within
the closure passed to the [`startWithSignal`][116] method.

#### Prefer managing lifetime with operators over explicit disposal

Although the [disposable][117] returned from [`start`][118] makes
canceling a [signal producer][119] really easy, explicit use of
disposables can quickly lead to a rat's nest of resource management and cleanup
code.

There are almost always higher-level [operators][120] that can be used instead of manual
disposal:

 * [`take`][121] can be used to automatically terminate a stream once a certain
   number of values have been received.
 * [`takeUntil`][122] can be used to automatically terminate
   a [signal][123] or producer when an event occurs (for example, when
   a “Cancel” button is pressed in the UI).
 * [Properties][124] and the `<~` operator can be used to “bind” the result of
   a signal or producer, until termination or until the property is deallocated.
   This can replace a manual observation that sets a value somewhere.

## Implementing new operators

RAC provides a long list of built-in [operators][125] that should cover most use
cases; however, RAC is not a closed system. It's entirely valid to implement
additional operators for specialized uses, or for consideration in ReactiveCocoa
itself.

Implementing a new operator requires a careful attention to detail and a focus
on simplicity, to avoid introducing bugs into the calling code.

These guidelines cover some of the common pitfalls and help preserve the
expected API contracts. It may also help to look at the implementations of
existing `Signal` and `SignalProducer` operators for reference points.

#### Prefer writing operators that apply to both signals and producers

Since any [signal operator can apply to signal
producers](#signal-operators-can-be-lifted-to-apply-to-signal-producers),
writing custom operators in terms of [`Signal`][126] means that
[`SignalProducer`][127] will get it “for free.”

Even if the caller only needs to apply the new operator to signal producers at
first, this generality can save time and effort in the future.

Of course, some capabilities _require_ producers (for example, any retrying or
repeating), so it may not always be possible to write a signal-based version
instead.

#### Compose existing operators when possible

Considerable thought has been put into the operators provided by RAC, and they
have been validated through automated tests and through their real world use in
other projects. An operator that has been written from scratch may not be as
robust, or might not handle a special case that the built-in operators are aware
of.

To minimize duplication and possible bugs, use the provided operators as much as
possible in a custom operator implementation. Generally, there should be very
little code written from scratch.

#### Forward failure and interruption events as soon as possible

Unless an operator is specifically built to handle
[failures][128] and
[interruption][129]
in a custom way, it should propagate those events to the observer as soon as
possible, to ensure that their semantics are honored.

#### Switch over `Event` values

Instead of using [`start(failed:completed:interrupted:next:)`][130] or
[`observe(failed:completed:interrupted:next:)`][131], create your own
[observer][132] to process raw [`Event`][133] values, and use
a `switch` statement to determine the event type.

For example:

\`\`\`swift
producer.start { event in
	switch event {
	case let .Next(value):
	    println("Next event: \(value)")
	
	case let .Failed(error):
	    println("Failed event: \(error)")
	
	case .Completed:
	    println("Completed event")
	
	case .Interrupted:
	    println("Interrupted event")
	}
}
\`\`\`

Since the compiler will generate a warning if the `switch` is missing any case,
this prevents mistakes in a custom operator’s event handling.

#### Avoid introducing concurrency

Concurrency is an extremely common source of bugs in programming. To minimize
the potential for deadlocks and race conditions, operators should not
concurrently perform their work.

Callers always have the ability to [observe events on a specific
scheduler](#observe-events-on-a-known-scheduler), and RAC offers built-in ways
to parallelize work, so custom operators don’t need to be concerned with it.

#### Avoid blocking in operators

Signal or producer operators should return a new signal or producer
(respectively) as quickly as possible. Any work that the operator needs to
perform should be part of the event handling logic, _not_ part of the operator
invocation itself.

This guideline can be safely ignored when the purpose of an operator is to
synchronously retrieve one or more values from a stream, like `single()` or
`wait()`.

[1]:	FrameworkOverview.md
[2]:	#the-event-contract
[3]:	#nexts-provide-values-or-indicate-the-occurrence-of-events
[4]:	#failures-behave-like-exceptions-and-propagate-immediately
[5]:	#completion-indicates-success
[6]:	#interruption-cancels-outstanding-work-and-usually-propagates-immediately
[7]:	#events-are-serial
[8]:	#events-cannot-be-sent-recursively
[9]:	#events-are-sent-synchronously-by-default
[10]:	#the-signal-contract
[11]:	#signals-start-work-when-instantiated
[12]:	#the-event-stream-of-the-signal-is-alive-until-the-underlying-observer-is-released
[13]:	#unreachable-signals-with-no-observer-would-be-terminated-without-an-event
[14]:	#observing-a-signal-does-not-have-side-effects-unless-the-signal-is-unreachable
[15]:	#all-observers-of-a-signal-see-the-same-events-in-the-same-order
[16]:	#terminating-events-dispose-of-signal-resources
[17]:	#the-signalproducer-contract
[18]:	#signal-producers-start-work-on-demand-by-creating-signals
[19]:	#each-produced-signal-may-send-different-events-at-different-times
[20]:	#signal-operators-can-be-lifted-to-apply-to-signal-producers
[21]:	#disposing-of-a-produced-signal-will-interrupt-it
[22]:	#best-practices
[23]:	#process-only-as-many-values-as-needed
[24]:	#observe-events-on-a-known-scheduler
[25]:	#switch-schedulers-in-as-few-places-as-possible
[26]:	#capture-side-effects-within-signal-producers
[27]:	#share-the-side-effects-of-a-signal-producer-by-sharing-one-produced-signal
[28]:	#prefer-managing-lifetime-with-operators-over-explicit-disposal
[29]:	#implementing-new-operators
[30]:	#prefer-writing-operators-that-apply-to-both-signals-and-producers
[31]:	#compose-existing-operators-when-possible
[32]:	#forward-failure-and-interruption-events-as-soon-as-possible
[33]:	#switch-over-event-values
[34]:	#avoid-introducing-concurrency
[35]:	#avoid-blocking-in-operators
[36]:	FrameworkOverview.md#events
[37]:	FrameworkOverview.md#signals
[38]:	FrameworkOverview.md#signal-producers
[39]:	BasicOperators.md
[40]:	BasicOperators.md
[41]:	../ReactiveCocoa/Swift/Signal.swift
[42]:	../ReactiveCocoa/Swift/Errors.swift
[43]:	../ReactiveCocoa/Swift/Signal.swift
[44]:	#completion-indicates-success
[45]:	#failures-behave-like-exceptions-and-propagate-immediately
[46]:	BasicOperators.md
[47]:	BasicOperators.md#flattening-producers
[48]:	FrameworkOverview.md#disposables
[49]:	BasicOperators.md
[50]:	FrameworkOverview.md#observers
[51]:	BasicOperators.md
[52]:	FrameworkOverview.md#observers
[53]:	../ReactiveCocoa/Swift/Signal.swift
[54]:	BasicOperators.md
[55]:	FrameworkOverview.md#schedulers
[56]:	FrameworkOverview.md#observers
[57]:	FrameworkOverview.md#signals
[58]:	../ReactiveCocoa/Swift/Signal.swift
[59]:	FrameworkOverview.md#events
[60]:	FrameworkOverview.md#observers
[61]:	../ReactiveCocoa/Swift/Signal.swift
[62]:	FrameworkOverview.md#observers
[63]:	../ReactiveCocoa/Swift/Signal.swift
[64]:	FrameworkOverview.md#observers
[65]:	FrameworkOverview.md#observers
[66]:	FrameworkOverview.md#observers
[67]:	../ReactiveCocoa/Swift/Signal.swift
[68]:	FrameworkOverview.md#observers
[69]:	#events-are-sent-synchronously-by-default
[70]:	#interruption-cancels-outstanding-work-and-usually-propagates-immediately
[71]:	FrameworkOverview.md#events
[72]:	FrameworkOverview.md#observers
[73]:	FrameworkOverview.md#disposables
[74]:	FrameworkOverview.md#signal-producers
[75]:	FrameworkOverview.md#signals
[76]:	../ReactiveCocoa/Swift/SignalProducer.swift
[77]:	../ReactiveCocoa/Swift/SignalProducer.swift
[78]:	../ReactiveCocoa/Swift/SignalProducer.swift
[79]:	FrameworkOverview.md#events
[80]:	FrameworkOverview.md#observers
[81]:	FrameworkOverview.md#events
[82]:	BasicOperators.md
[83]:	../ReactiveCocoa/Swift/SignalProducer.swift
[84]:	#signal-producers-start-work-on-demand-by-creating-signals
[85]:	../ReactiveCocoa/Swift/SignalProducer.swift
[86]:	../ReactiveCocoa/Swift/SignalProducer.swift
[87]:	FrameworkOverview.md#disposables
[88]:	#interruption-cancels-outstanding-work-and-usually-propagates-immediately
[89]:	FrameworkOverview.md#events
[90]:	FrameworkOverview.md#observers
[91]:	../ReactiveCocoa/Swift/Disposable.swift
[92]:	../ReactiveCocoa/Swift/SignalProducer.swift
[93]:	FrameworkOverview.md#signals
[94]:	FrameworkOverview.md#signal-producers
[95]:	../ReactiveCocoa/Swift/Signal.swift
[96]:	../ReactiveCocoa/Swift/Signal.swift
[97]:	FrameworkOverview.md#signals
[98]:	FrameworkOverview.md#signal-producers
[99]:	FrameworkOverview.md#events
[100]:	#events-are-serial
[101]:	../ReactiveCocoa/Swift/Signal.swift
[102]:	BasicOperators.md
[103]:	FrameworkOverview.md#schedulers
[104]:	#observe-events-on-a-known-scheduler
[105]:	FrameworkOverview.md#events
[106]:	FrameworkOverview.md#schedulers
[107]:	../ReactiveCocoa/Swift/Signal.swift
[108]:	FrameworkOverview.md#signals
[109]:	FrameworkOverview.md#signal-producers
[110]:	FrameworkOverview.md#properties
[111]:	FrameworkOverview.md#signal-producers
[112]:	FrameworkOverview.md#observers
[113]:	FrameworkOverview.md#signal-producers
[114]:	../ReactiveCocoa/Swift/SignalProducer.swift
[115]:	FrameworkOverview.md#signals
[116]:	../ReactiveCocoa/Swift/SignalProducer.swift
[117]:	FrameworkOverview.md#disposables
[118]:	../ReactiveCocoa/Swift/SignalProducer.swift
[119]:	FrameworkOverview.md#signal-producers
[120]:	BasicOperators.md
[121]:	../ReactiveCocoa/Swift/Signal.swift
[122]:	../ReactiveCocoa/Swift/Signal.swift
[123]:	FrameworkOverview.md#signals
[124]:	FrameworkOverview.md#properties
[125]:	BasicOperators.md
[126]:	FrameworkOverview.md#signals
[127]:	FrameworkOverview.md#signal-producers
[128]:	#failures-behave-like-exceptions-and-propagate-immediately
[129]:	#interruption-cancels-outstanding-work-and-usually-propagates-immedaitely
[130]:	../ReactiveCocoa/Swift/SignalProducer.swift
[131]:	../ReactiveCocoa/Swift/Signal.swift
[132]:	FrameworkOverview.md#observers
[133]:	FrameworkOverview.md#events