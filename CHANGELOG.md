# 4.0 

**The RAC 4 APIs are work in progress**. There may be significant breaking
changes in later alphas so be prepared for that before taking a dependency.

If you're new to the Swift API and migrating from RAC 2, start with the
[3.0 changes](#30). This section only covers the differences between 3.0 and
4.0.

ReactiveCocoa 4.0 targets Swift 2 and the current focus is on leveraging the
improvements from Swift 1.2 to provide a simpler API.

## Alpha 1

#### Signal operators are protocol extensions

The biggest change from RAC 3 to RAC 4 is that signal and producer operators
are implemented as protocol extensions instead of global functions. This is
similar to many of the collection protocol changes in the Swift 2 standard
library.

This enables chaining signal operators with normal dot-method calling syntax.
Previously the custom `|>` was required to enable chaining global functions
without a mess of nested calls and parenthesis.

```swift
/// RAC 3
signal |> filter { $0 % 2 == 0 } |> map { $0 * $0 } |> observe { print($0) }

/// RAC 4
signal.filter { $0 % 2 == 0 } .map { $0 * $0 } .observe { print($0) }
```

Additionally, this means that `SignalProducer` operators are less "magic". In
RAC 3 the `Signal` operators were implicitly lifted to work on `SignalProducer`
via `|>`. This was a point of confusion for some, especially when browsing the
source looking for these operators. Now as protocol extensions, the
`SignalProducer` operators are explicitly implementated in terms of their
`Signal` counterpart when available.

#### Removal of |> custom operator

As already alluded to above, the custom `|>` operator for chaining signals has
been removed. Instead standard method calling syntax is used for chaining
operators.

#### Event.Sink is now a function

With the removal of `SinkType` in Swift 2, the `Event.Sink` type is now just a
function `Event -> ()`.

#### Event cases are no longer boxed

The improvements to associated enum values in Swift 2 mean that `Event` cases
no longer need to be `Box`ed. In fact, the `Box` dependency has been removed
completely from RAC 4.

#### Replacements for the start and observer overloads

_These are likely to see further changes in a later alpha_

The `observe` and `start` overloads taking `next`, `error`, etc. optional
function parameters have been removed. This was necessitated by the change to
`Event.Sink` becoming a function type which introduced an unresolvable
ambiguity. They've been replaced with methods taking a single function with
the target `Event` case -- `observeNext`, `startWithNext`, and the same for
error and completed. See #2311 and #2318 for more details.

#### Renamed try and catch operators

The `try` and `catch` operators were renamed because of the addition of the
error handling keywords with the same name. They are now `attempt` and
`flatMapError` respectively. Also, `tryMap` was renamed to `attemptMap` for
consistency.

#### Added flatten and flatMap for signal-of-producers

This fills a gap that was missing in RAC 3. It's a common pattern to have a
hot `Signal` of values that need to be mapped to "work" -- `SignalProducer`.
The addition of `flatten` and `flatMap` over signals-of-producers makes it
easy to serialize (`Concat`) or parallelize (`Merge`) the work, or only run
the most recent (`Latest`).

#### Renaming T and E generic parameters

Probably coming to later alpha. See #2212 and #2349.

#### Renaming Event.Error to Event.Failed

Maybe coming to a later alpha. See #2360.

# 3.0

ReactiveCocoa 3.0 includes the first official Swift API, which is intended to
eventually supplant the Objective-C API entirely.

However, because migration is hard and time-consuming, and because Objective-C
is still in widespread use, 99% of RAC 2.x code will continue to work under RAC
3.0 without any changes.

Since the 3.0 changes are entirely additive, this document will discuss how
concepts from the Objective-C API map to the Swift API. For a complete diff of
all changes, see [the 3.0 pull
request](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/1382).

**[Additions](#additions)**

 1. [Parameterized types](#parameterized-types)
 1. [Interrupted event](#interrupted-event)
 1. [Objective-C bridging](#objective-c-bridging)

**[Replacements](#replacements)**

 1. [Hot signals are now Signals](#hot-signals-are-now-signals)
 1. [Cold signals are now SignalProducers](#cold-signals-are-now-signalproducers)
 1. [Commands are now Actions](#commands-are-now-actions)
 1. [Flattening/merging, concatenating, and switching are now one operator](#flatteningmerging-concatenating-and-switching-are-now-one-operator)
 1. [Using PropertyType instead of RACObserve and RAC](#using-propertytype-instead-of-racobserve-and-rac)
 1. [Using Signal.pipe instead of RACSubject](#using-signalpipe-instead-of-racsubject)
 1. [Using SignalProducer.buffer instead of replaying](#using-signalproducerbuffer-instead-of-replaying)
 1. [Using startWithSignal instead of multicasting](#using-startwithsignal-instead-of-multicasting)

**[Minor changes](#minor-changes)**

 1. [Disposable changes](#disposable-changes)
 1. [Scheduler changes](#scheduler-changes)

## Additions

### Parameterized types

Thanks to Swift, **it is now possible to express the type of value that a signal
can send. RAC also requires that the type of errors be specified.**

For example, `Signal<Int, NSError>` is a signal that may send zero or more
integers, and which may send an error of type `NSError`.

**If it is impossible for a signal to error out, use the built-in
[`NoError`](ReactiveCocoa/Swift/Errors.swift) type**
(which can be referred to, but never created) to represent that
case—for example, `Signal<String, NoError>` is a signal that may send zero or
more strings, and which will _not_ send an error under any circumstances.

Together, these additions make it much simpler to reason about signal
interactions, and protect against several kinds of common bugs that occurred in
Objective-C.

### Interrupted event

In addition to the `Next`, `Error`, and `Completed` events that have always been
part of RAC, version 3.0 [adds another terminating
event](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/1735)—called
`Interrupted`—that is used to communicate cancellation.

Now, **whenever a [producer](#cold-signals-are-now-signalproducers) is disposed
of, one final `Interrupted` event will be sent to all consumers,** giving them
a chance to react to the cancellation.

Similarly, observing a [hot signal](#hot-signals-are-now-signals) that has
already terminated will immediately result in an `Interrupted` event, to clearly
indicate that no further events are possible.

This brings disposal semantics more in line with normal event delivery, where
events propagate downstream from producers to consumers. The result is a simpler
model for reasoning about non-erroneous, yet unsuccessful, signal terminations.

**Note:** Custom `Signal` and `SignalProducer` operators should handle any received
`Interrupted` event by forwarding it to their own observers. This ensures that
interruption correctly propagates through the whole signal chain.

### Objective-C bridging

**To support interoperation between the Objective-C APIs introduced in RAC 2 and
the Swift APIs introduced in RAC 3, the framework offers [bridging
functions](ReactiveCocoa/Swift/ObjectiveCBridging.swift)** that can convert types
back and forth between the two.

Because the APIs are based on fundamentally different designs, the conversion is
not always one-to-one; however, every attempt has been made to faithfully
translate the concepts between the two APIs (and languages).

**Common conversions include:**

* The `RACSignal.toSignalProducer` method **†**
    * Converts `RACSignal *` to `SignalProducer<AnyObject?, NSError>`
* The `toRACSignal()` function
    * Converts `SignalProducer<AnyObject?, ErrorType>` to `RACSignal *`
    * Converts `Signal<AnyObject?, ErrorType>` to `RACSignal *`
* The `RACCommand.toAction` method **‡**
    * Converts `RACCommand *` to `Action<AnyObject?, AnyObject?, NSError>`
* The `toRACCommand` function **‡**
    * Converts `Action<AnyObject?, AnyObject?, ErrorType>` to `RACCommand *`

**†** It is not possible (in the general case) to convert arbitrary `RACSignal`
instances to `Signal`s, because any `RACSignal` subscription could potentially
involve side effects. To obtain a `Signal`, use `RACSignal.toSignalProducer`
followed by `SignalProducer.start`, thereby making those side effects explicit.

**‡** Unfortunately, the `executing` properties of actions and commands are not
synchronized across the API bridge. To ensure consistency, only observe the
`executing` property from the base object (the one passed _into_ the bridge, not
retrieved from it), so updates occur no matter which object is used for
execution.

## Replacements

### Hot signals are now Signals

In the terminology of RAC 2, a “hot” `RACSignal` does not trigger any side effects
when a `-subscribe…` method is called upon it. In other words, hot signals are
entirely producer-driven and push-based, and consumers (subscribers) cannot have
any effect on their lifetime.

This pattern is useful for notifying observers about events that will occur _no
matter what_. For example, a `loading` boolean might flip between true and false
regardless of whether anything is observing it.

Concretely, _every_ `RACSubject` is a kind of hot signal, because the events
being forwarded are not determined by the number of subscribers on the subject.

In RAC 3, **“hot” signals are now solely represented by the
[`Signal`](ReactiveCocoa/Swift/Signal.swift) class**, and “cold” signals have been
[separated into their own type](#cold-signals-are-now-signalproducers). This
reduces complexity by making it clear that no `Signal` object can trigger side
effects when observed.

### Cold signals are now SignalProducers

In the terminology of RAC 2, a “cold” `RACSignal` performs its work one time for
_every_ subscription. In other words, cold signals perform side effects when
a `-subscribe…` method is called upon them, and may be able to cancel
in-progress work if `-dispose` is called upon the returned `RACDisposable`.

This pattern is broadly useful because it minimizes unnecessary work, and
allows operators like `take`, `retry`, `concat`, etc. to manipulate when work is
started and cancelled. Cold signals are also similar to how [futures and
promises](http://en.wikipedia.org/wiki/Futures_and_promises) work, and can be
useful for structuring asynchronous code (like network requests).

In RAC 3, **“cold” signals are now solely represented by the
[`SignalProducer`](ReactiveCocoa/Swift/SignalProducer.swift) class**, which
clearly indicates their relationship to [“hot”
signals](#hot-signals-are-now-signals). As the name indicates, a signal
_producer_ is responsible for creating
a [_signal_](#hot-signals-are-now-signals) (when started), and can
perform work as part of that process—meanwhile, the signal can have any number
of observers without any additional side effects.

### Commands are now Actions

Instead of the ambiguously named `RACCommand`, the Swift API offers the
[`Action`](ReactiveCocoa/Swift/Action.swift) type—named as such because it’s
mainly useful in UI programming—to fulfill the same purpose.

Like the rest of the Swift API, actions are
[parameterized](#parameterized-types) by the types they use. **An action must
indicate the type of input it accepts, the type of output it produces, and
what kinds of errors can occur (if any).** This eliminates a few classes of type
error, and clarifies intention.

Actions are also intended to be simpler overall than their predecessor:

 * **Unlike commands, actions are not bound to or dependent upon the main
   thread**, making it easier to reason about when they can be executed and when
   they will generate notifications.
 * **Actions also only support serial execution**, because concurrent execution
   was a rarely used feature of `RACCommand` that added significant complexity
   to the interface and implementation.

Because actions are frequently used in conjunction with AppKit or UIKit, there
is also a `CocoaAction` class that erases the type parameters of an `Action`,
allowing it to be used from Objective-C.

As an example, an action can be wrapped and bound to `UIControl` like so:

```swift
self.cocoaAction = CocoaAction(underlyingAction)
self.button.addTarget(self.cocoaAction, action: CocoaAction.selector, forControlEvents: UIControlEvents.TouchUpInside)
```

### Flattening/merging, concatenating, and switching are now one operator

RAC 2 offers several operators for transforming a signal-of-signals into one
`RACSignal`, including:

 * `-flatten`
 * `-flattenMap:`
 * `+merge:`
 * `-concat`
 * `+concat:`
 * `-switchToLatest`

Because `-flattenMap:` is the easiest to use, it was often
incorrectly chosen even when concatenation or switching semantics are more
appropriate.

**RAC 3 distills these concepts down into just two operators, `flatten` and `flatMap`.**
Note that these do _not_ have the same behavior as `-flatten` and `-flattenMap:`
from RAC 2. Instead, both accept a “strategy” which determines how the
producer-of-producers should be integrated, which can be one of:

 * `.Merge`, which is equivalent to RAC 2’s `-flatten` or `+merge:`
 * `.Concat`, which is equivalent to `-concat` or `+concat:`
 * `.Latest`, which is equivalent to `-switchToLatest`

This reduces the API surface area, and forces callers to consciously think about
which strategy is most appropriate for a given use.

**For streams of exactly one value, calls to `-flattenMap:` can be replaced with
`flatMap(.Concat)`**, which has the additional benefit of predictable behavior if
the input stream is refactored to have more values in the future.

### Using PropertyType instead of RACObserve and RAC

To be more Swift-like, RAC 3 de-emphasizes [Key-Value Coding](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/KeyValueCoding.html) (KVC)
and [Key-Value Observing](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) (KVO)
in favor of a less “magical” representation for properties.
**The [`PropertyType` protocol and implementations](ReactiveCocoa/Swift/Property.swift)
replace most uses of the `RACObserve()` and `RAC()` macros.**

For example, `MutableProperty` can be used to represent a property that can be
bound to. If changes to that property should be visible to consumers, it can
additionally be wrapped in `PropertyOf` (to hide the mutable bits) and exposed
publicly.

**If KVC or KVO is required by a specific API**—for example, to observe changes
to `NSOperation.executing`—RAC 3 offers a `DynamicProperty` type that can wrap
those key paths. Use this class with caution, though, as it can’t offer any type
safety, and many APIs (especially in AppKit and UIKit) are not documented to be
KVO-compliant.

### Using Signal.pipe instead of RACSubject

Since the `Signal` type, like `RACSubject`, is [always “hot”](#hot-signals-are-now-signals),
there is a special class method for creating a controllable signal. **The
`Signal.pipe` method can replace the use of subjects**, and expresses intent
better by separating the observing API from the sending API.

To use a pipe, set up observers on the signal as desired, then send values to
the sink:

```swift
let (signal, sink) = Signal<Int, NoError>.pipe()

signal.observe(next: { value in
    println(value)
})

// Prints each number
sendNext(sink, 0)
sendNext(sink, 1)
sendNext(sink, 2)
```

### Using SignalProducer.buffer instead of replaying

The producer version of
[`Signal.pipe`](#using-signalpipe-instead-of-racsubject),
**the `SignalProducer.buffer` method can replace replaying** with
`RACReplaySubject` or any of the `-replay…` methods.

Conceptually, `buffer` creates a (optionally bounded) queue for events, much
like `RACReplaySubject`, and replays those events when new `Signal`s are created
from the producer.

For example, to replay the values of an existing `Signal`, it just needs to be
fed into the write end of the buffer:

```swift
let signal: Signal<Int, NoError>
let (producer, sink) = SignalProducer<Int, NoError>.buffer()

// Saves observed values in the buffer
signal.observe(sink)

// Prints each value buffered
producer.start(next: { value in
    println(value)
})
```

### Using startWithSignal instead of multicasting

`RACMulticastConnection` and the `-publish` and `-multicast:` operators were
always poorly understood features of RAC 2. In RAC 3, thanks to the `Signal` and
`SignalProducer` split, **the `SignalProducer.startWithSignal` method can
replace multicasting**.

`startWithSignal` allows any number of observers to attach to the created signal
_before_ any work is begun—therefore, the work (and any side effects) still
occurs just once, but the values can be distributed to multiple interested
observers. This fulfills the same purpose of multicasting, in a much clearer and
more tightly-scoped way.

For example:

```swift
let producer = timer(5, onScheduler: QueueScheduler.mainQueueScheduler).take(3)

// Starts just one timer, sending the dates to two different observers as they
// are generated.
producer.startWithSignal { signal, disposable in
    signal.observe(next: { date in
        println(date)
    })

    signal.observe(someOtherObserver)
}
```

## Minor changes

### Disposable changes

[Disposables](ReactiveCocoa/Swift/Disposable.swift) haven’t changed much overall
in RAC 3, besides the addition of a protocol and minor naming tweaks.

The biggest change to be aware of is that **setting
`SerialDisposable.innerDisposable` will always dispose of the previous value**,
which helps prevent resource leaks or logic errors from forgetting to dispose
manually.

### Scheduler changes

RAC 3 replaces the multipurpose `RACScheduler` class with two protocols,
[`SchedulerType` and `DateSchedulerType`](ReactiveCocoa/Swift/Scheduler.swift), with multiple implementations of each.
This design indicates and enforces the capabilities of each scheduler using the type
system.

In addition, **the `mainThreadScheduler` has been replaced with `UIScheduler` and
`QueueScheduler.mainQueueScheduler`**. The `UIScheduler` type runs operations as
soon as possible on the main thread—even synchronously (if possible), thereby
replacing RAC 2’s `-performOnMainThread` operator—while
`QueueScheduler.mainQueueScheduler` will always enqueue work after the current
run loop iteration, and can be used to schedule work at a future date.
