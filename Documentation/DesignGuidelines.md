# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

This document assumes basic familiarity
with the features of ReactiveCocoa. The [Framework Overview][] is a better
resource for getting up to speed on the main types and concepts provided by RAC.

**[The `Event` contract](#the-event-contract)**

 1. [`Next`s provide values or indicate the occurrence of events](#nexts-provide-values-or-indicate-the-occurrence-of-events)
 1. [Failures behave like exceptions and propagate immediately](#failures-behave-like-exceptions-and-propagate-immediately)
 1. [Completion indicates success](#completion-indicates-success)
 1. [Interruption cancels outstanding work and usually propagates immediately](#interruption-cancels-outstanding-work-and-usually-propagates-immediately)
 1. [Events are serial](#events-are-serial)
 1. [Events cannot be sent recursively](#events-cannot-be-sent-recursively)
 1. [Events are sent synchronously by default](#events-are-sent-synchronously-by-default)

**[The `Signal` contract](#the-signal-contract)**

 1. [Signals start work when instantiated](#signals-start-work-when-instantiated)
 1. [Observing a signal does not have side effects](#observing-a-signal-does-not-have-side-effects)
 1. [All observers of a signal see the same events in the same order](#all-observers-of-a-signal-see-the-same-events-in-the-same-order)
 1. [A signal is retained until the underlying observer is released](#a-signal-is-retained-until-the-underlying-observer-is-released)
 1. [Terminating events dispose of signal resources](#terminating-events-dispose-of-signal-resources)

**[The `SignalProducer` contract](#the-signalproducer-contract)**

 1. [Signal producers start work on demand by creating signals](#signal-producers-start-work-on-demand-by-creating-signals)
 1. [Each produced signal may send different events at different times](#each-produced-signal-may-send-different-events-at-different-times)
 1. [Signal operators can be lifted to apply to signal producers](#signal-operators-can-be-lifted-to-apply-to-signal-producers)
 1. [Disposing of a produced signal will interrupt it](#disposing-of-a-produced-signal-will-interrupt-it)

**[Best practices](#best-practices)**

 1. [Process only as many values as needed](#process-only-as-many-values-as-needed)
 1. [Observe events on a known scheduler](#observe-events-on-a-known-scheduler)
 1. [Switch schedulers in as few places as possible](#switch-schedulers-in-as-few-places-as-possible)
 1. [Capture side effects within signal producers](#capture-side-effects-within-signal-producers)
 1. [Share the side effects of a signal producer by sharing one produced signal](#share-the-side-effects-of-a-signal-producer-by-sharing-one-produced-signal)
 1. [Prefer managing lifetime with operators over explicit disposal](#prefer-managing-lifetime-with-operators-over-explicit-disposal)

**[Implementing new operators](#implementing-new-operators)**

 1. [Prefer writing operators that apply to both signals and producers](#prefer-writing-operators-that-apply-to-both-signals-and-producers)
 1. [Compose existing operators when possible](#compose-existing-operators-when-possible)
 1. [Forward failure and interruption events as soon as possible](#forward-failure-and-interruption-events-as-soon-as-possible)
 1. [Switch over `Event` values](#switch-over-event-values)
 1. [Avoid introducing concurrency](#avoid-introducing-concurrency)
 1. [Avoid blocking in operators](#avoid-blocking-in-operators)

## The `Event` contract

[Events][] are fundamental to ReactiveCocoa. [Signals][] and [signal producers][] both send
events, and may be collectively called “event streams.”

Event streams must conform to the following grammar:

```
Next* (Interrupted | Failed | Completed)?
```

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

Most of the event stream [operators][] act upon `Next` events, as they represent the
“meaningful data” of a signal or producer.

#### Failures behave like exceptions and propagate immediately

`Failed` events indicate that something went wrong, and contain a concrete error
that indicates what happened. Failures are fatal, and propagate as quickly as
possible to the consumer for handling.

Failures also behave like exceptions, in that they “skip” operators, terminating
them along the way. In other words, most [operators][] immediately stop doing
work when a failure is received, and then propagate the failure onward. This even applies to time-shifted operators, like [`delay`][delay]—which, despite its name, will forward any failures immediately.

Consequently, failures should only be used to represent “abnormal” termination. If it is important to let operators (or consumers) finish their work, a `Next`
event describing the result might be more appropriate.

If an event stream can _never_ fail, it should be parameterized with the
special [`NoError`][NoError] type, which statically guarantees that a `Failed`
event cannot be sent upon the stream.

#### Completion indicates success

An event stream sends `Completed` when the operation has completed successfully,
or to indicate that the stream has terminated normally.

Many operators manipulate the `Completed` event to shorten or extend the
lifetime of an event stream.

For example, [`take`][take] will complete after the specified number of values have
been received, thereby terminating the stream early. On the other hand, most
operators that accept multiple signals or producers will wait until _all_ of
them have completed before forwarding a `Completed` event, since a successful
outcome will usually depend on all the inputs.

#### Interruption cancels outstanding work and usually propagates immediately

An `Interrupted` event is sent when an event stream should cancel processing.
Interruption is somewhere between [success](#completion-indicates-success)
and [failure](#failures-behave-like-exceptions-and-propagate-immediately)—the
operation was not successful, because it did not get to finish, but it didn’t
necessarily “fail” either.

Most [operators][] will propagate interruption immediately, but there are some
exceptions. For example, the [flattening operators][flatten] will ignore
`Interrupted` events that occur on the _inner_ producers, since the cancellation
of an inner operation should not necessarily cancel the larger unit of work.

RAC will automatically send an `Interrupted` event upon [disposal][Disposables], but it can
also be sent manually if necessary. Additionally, [custom
operators](#implementing-new-operators) must make sure to forward interruption
events to the observer.

#### Events are serial

RAC guarantees that all events upon a stream will arrive serially. In other
words, it’s impossible for the observer of a signal or producer to receive
multiple `Event`s concurrently, even if the events are sent on multiple threads
simultaneously.

This simplifies [operator][Operators] implementations and [observers][].

#### Events cannot be sent recursively

Just like RAC guarantees that [events will not be received
concurrently](#events-are-serial), it also guarantees that they won’t be
received recursively. As a consequence, [operators][] and [observers][] _do not_ need to
be reentrant.

If an event is sent upon a signal from a thread that is _already processing_
a previous event from that signal, deadlock will result. This is because
recursive signals are usually programmer error, and the determinacy of
a deadlock is preferable to nondeterministic race conditions.

When a recursive signal is explicitly desired, the recursive event should be
time-shifted, with an operator like [`delay`][delay], to ensure that it isn’t sent from
an already-running event handler.

#### Events are sent synchronously by default

RAC does not implicitly introduce concurrency or asynchrony. [Operators][] that
accept a [scheduler][Schedulers] may, but they must be explicitly invoked by the consumer of
the framework.

A “vanilla” signal or producer will send all of its events synchronously by
default, meaning that the [observer][Observers] will be synchronously invoked for each event
as it is sent, and that the underlying work will not resume until the event
handler finishes.

This is similar to how `NSNotificationCenter` or `UIControl` events are
distributed.

## The `Signal` contract

A [signal][Signals] is an “always on” stream that obeys [the `Event`
contract](#the-event-contract).

`Signal` is a reference type, because each signal has identity—in other words, each
signal has its own lifetime, and may eventually terminate. Once terminated,
a signal cannot be restarted.

#### Signals start work when instantiated

[`Signal.init`][Signal.init] immediately executes the generator closure that is passed to it.
This means that side effects may occur even before the initializer returns.

It is also possible to send [events][] before the initializer returns. However,
since it is impossible for any [observers][] to be attached at this point, any
events sent this way cannot be received.

#### Observing a signal does not have side effects

The work associated with a `Signal` does not start or stop when [observers][] are
added or removed, so the [`observe`][observe] method (or the cancellation thereof) never
has side effects.

A signal’s side effects can only be stopped through [a terminating
event](#signals-are-retained-until-a-terminating-event-occurs).

#### All observers of a signal see the same events in the same order

Because [observation does not have side
effects](#observing-a-signal-does-not-have-side-effects), a `Signal` never
customizes events for different [observers][]. When an event is sent upon a signal,
it will be [synchronously](#events-are-sent-synchronously-by-default)
distributed to all observers that are attached at that time, much like
how `NSNotificationCenter` sends notifications.

In other words, there are not different event “timelines” per observer. All
observers effectively see the same stream of events.

There is one exception to this rule: adding an observer to a signal _after_ it
has already terminated will result in exactly one
[`Interrupted`](#interruption-cancels-outstanding-work-and-usually-propagates-immediately)
event sent to that specific observer.

#### A signal is retained until the underlying observer is released

Even if the caller does not maintain a reference to the `Signal`:

 - A signal created with [`Signal.init`][Signal.init] is kept alive until the generator closure
   releases the [observer][Observers] argument.
 - A signal created with [`Signal.pipe`][Signal.pipe] is kept alive until the returned observer
   is released.

This ensures that signals associated with long-running work do not deallocate
prematurely.

Note that it is possible to release a signal before a terminating [event][Events] has been
sent upon it. This should usually be avoided, as it can result in resource
leaks, but is sometimes useful to disable termination.

#### Terminating events dispose of signal resources

When a terminating [event][Events] is sent along a `Signal`, all [observers][] will be
released, and any resources being used to generate events should be disposed of.

The easiest way to ensure proper resource cleanup is to return a [disposable][Disposables]
from the generator closure, which will be disposed of when termination occurs.
The disposable should be responsible for releasing memory, closing file handles,
canceling network requests, or anything else that may have been associated with
the work being performed.

## The `SignalProducer` contract

A [signal producer][Signal Producers] is like a “recipe” for creating
[signals][]. Signal producers do not do anything by themselves—[work begins only
when a signal is produced](#signal-producers-start-work-on-demand-by-creating-signals).

Since a signal producer is just a declaration of _how_ to create signals, it is
a value type, and has no memory management to speak of.

#### Signal producers start work on demand by creating signals

The [`start`][start] and [`startWithSignal`][startWithSignal] methods each
produce a `Signal` (implicitly and explicitly, respectively). After
instantiating the signal, the closure that was passed to
[`SignalProducer.init`][SignalProducer.init] will be executed, to start the flow
of [events][] after any observers have been attached.

Although the producer itself is not _really_ responsible for the execution of
work, it’s common to speak of “starting” and “canceling” a producer. These terms
refer to producing a `Signal` that will start work, and [disposing of that
signal](#disposing-of-a-produced-signal-will-interrupt-it) to stop work.

A producer can be started any number of times (including zero), and the work
associated with it will execute exactly that many times as well.

#### Each produced signal may send different events at different times

Because signal producers [start work on
demand](#signal-producers-start-work-on-demand-by-creating-signals), there may
be different [observers][] associated with each execution, and those observers
may see completely different [event][Events] timelines.

In other words, events are generated from scratch for each time the producer is
started, and can be completely different (or in a completely different order)
from other times the producer is started.

Nonetheless, each execution of a signal producer will follow [the `Event`
contract](#the-event-contract).

#### Signal operators can be lifted to apply to signal producers

Due to the relationship between signals and signal producers, it is possible to
automatically promote any [operators][] over one or more `Signal`s to apply to
the same number of `SignalProducer`s instead, using the [`lift`][lift] method.

`lift` will apply the behavior of the specified operator to each `Signal` that
is [created when the signal producer is started](#signal-producers-start-work-on-demand-by-creating-signals).

#### Disposing of a produced signal will interrupt it

When a producer is started using the [`start`][start] or
[`startWithSignal`][startWithSignal] methods, a [`Disposable`][Disposables] is
automatically created and passed back.

Disposing of this object will
[interrupt](#interruption-cancels-outstanding-work-and-usually-propagates-immediately)
the produced `Signal`, thereby canceling outstanding work and sending an
`Interrupted` [event][Events] to all [observers][], and will also dispose of
everything added to the [`CompositeDisposable`][CompositeDisposable] in
[SignalProducer.init].

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
a [signal][Signals] or [producer][Signal Producers], operators like
[`take`][take] or [`takeUntil`][takeUntil] can be used to
automatically complete the stream once a certain condition is fulfilled.

The benefit is exponential, too, as this will terminate dependent operators
sooner, potentially saving a significant amount of work.

#### Observe events on a known scheduler

When receiving a [signal][Signals] or [producer][Signal Producers] from unknown
code, it can be difficult to know which thread [events][] will arrive upon. Although
events are [guaranteed to be serial](#events-are-serial), sometimes stronger
guarantees are needed, like when performing UI updates (which must occur on the
main thread).

Whenever such a guarantee is important, the [`observeOn`][observeOn]
[operator][Operators] should be used to force events to be received upon
a specific [scheduler][Schedulers].

#### Switch schedulers in as few places as possible

Notwithstanding the [above](#observe-events-on-a-known-scheduler), [events][]
should only be delivered to a specific [scheduler][Schedulers] when absolutely
necessary. Switching schedulers can introduce unnecessary delays and cause an
increase in CPU load.

Generally, [`observeOn`][observeOn] should only be used right before observing
the [signal][Signals], starting the [producer][Signal Producers], or binding to
a [property][Properties]. This ensures that events arrive on the expected
scheduler, without introducing multiple thread hops before their arrival.

#### Capture side effects within signal producers

Because [signal producers start work on
demand](#signal-producers-start-work-on-demand-by-creating-signals), any
functions or methods that return a [signal producer][Signal Producers] should
make sure that side effects are captured _within_ the producer itself, instead
of being part of the function or method call.

For example, a function like this:

```swift
func search(text: String) -> SignalProducer<Result, NetworkError>
```

… should _not_ immediately start a search.

Instead, the returned producer should execute the search once for every time
that it is started. This also means that if the producer is never started,
a search will never have to be performed either.

#### Share the side effects of a signal producer by sharing one produced signal

If multiple [observers][] are interested in the results of a [signal
producer][Signal Producers], calling [`start`][start] once for each observer
means that the work associated with the producer will [execute that many
times](#signal-producers-start-work-on-demand-by-creating-signals) and [may not
generate the same results](#each-produced-signal-may-send-different-events-at-different-times).

If:

 1. the observers need to receive the exact same results
 1. the observers know about each other, or
 1. the code starting the producer knows about each observer

… it may be more appropriate to start the producer _just once_, and share the
results of that one [signal][Signals] to all observers, by attaching them within
the closure passed to the [`startWithSignal`][startWithSignal] method.

#### Prefer managing lifetime with operators over explicit disposal

Although the [disposable][Disposables] returned from [`start`][start] makes
canceling a [signal producer][Signal Producers] really easy, explicit use of
disposables can quickly lead to a rat's nest of resource management and cleanup
code.

There are almost always higher-level [operators][] that can be used instead of manual
disposal:

 * [`take`][take] can be used to automatically terminate a stream once a certain
   number of values have been received.
 * [`takeUntil`][takeUntil] can be used to automatically terminate
   a [signal][Signals] or producer when an event occurs (for example, when
   a “Cancel” button is pressed in the UI).
 * [Properties][] and the `<~` operator can be used to “bind” the result of
   a signal or producer, until termination or until the property is deallocated.
   This can replace a manual observation that sets a value somewhere.

## Implementing new operators

RAC provides a long list of built-in [operators][] that should cover most use
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
writing custom operators in terms of [`Signal`][Signals] means that
[`SignalProducer`][Signal Producers] will get it “for free.”

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
[failures](#failures-behave-like-exceptions-and-propagate-immediately) and
[interruption](#interruption-cancels-outstanding-work-and-usually-propagates-immedaitely)
in a custom way, it should propagate those events to the observer as soon as
possible, to ensure that their semantics are honored.

#### Switch over `Event` values

Instead of using [`start(failed:completed:interrupted:next:)`][start] or
[`observe(failed:completed:interrupted:next:)`][observe], create your own
[observer][Observers] to process raw [`Event`][Events] values, and use
a `switch` statement to determine the event type.

For example:

```swift
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
```

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

[CompositeDisposable]: ../ReactiveCocoa/Swift/Disposable.swift
[Disposables]: FrameworkOverview.md#disposables
[Events]: FrameworkOverview.md#events
[Framework Overview]: FrameworkOverview.md
[NoError]: ../ReactiveCocoa/Swift/Errors.swift
[Observers]: FrameworkOverview.md#observers
[Operators]: BasicOperators.md
[Properties]: FrameworkOverview.md#properties
[Schedulers]: FrameworkOverview.md#schedulers
[Signal Producers]: FrameworkOverview.md#signal-producers
[Signal.init]: ../ReactiveCocoa/Swift/Signal.swift
[Signal.pipe]: ../ReactiveCocoa/Swift/Signal.swift
[SignalProducer.init]: ../ReactiveCocoa/Swift/SignalProducer.swift
[Signals]: FrameworkOverview.md#signals
[delay]: ../ReactiveCocoa/Swift/Signal.swift
[flatten]: BasicOperators.md#flattening-producers
[lift]: ../ReactiveCocoa/Swift/SignalProducer.swift
[observe]: ../ReactiveCocoa/Swift/Signal.swift
[observeOn]: ../ReactiveCocoa/Swift/Signal.swift
[start]: ../ReactiveCocoa/Swift/SignalProducer.swift
[startWithSignal]: ../ReactiveCocoa/Swift/SignalProducer.swift
[take]: ../ReactiveCocoa/Swift/Signal.swift
[takeUntil]: ../ReactiveCocoa/Swift/Signal.swift
