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
 1. [Flattening/merging, concatenating, and switching are now one operator](#)
 1. Using PropertyType instead of RACObserve and RAC
 1. Using Signal.pipe instead of RACSubject
 1. Using SignalProducer.buffer instead of replaying
 1. Using startWithSignal instead of multicasting

**[Minor changes](#minor-changes)**

 1. Disposable changes
 1. Scheduler changes

## Additions

### Parameterized types

Thanks to Swift, it is now possible to express the type of value that a signal
can send. RAC also requires that the type of errors be specified.

For example, `Signal<Int, NSError>` is a signal that may send zero or more
integers, and which may send an error of type `NSError`.

If it is impossible for a signal to error out, the built-in `NoError` type
(which can be referred to, but never created) can be used to represent that
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

Now, whenever a [producer](#cold-signals-are-now-signalproducers) is disposed
of, one final `Interrupted` event will be sent to all consumers, giving them
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

To support interoperation between the Objective-C APIs introduced in RAC 2 and
the Swift APIs introduced in RAC 3, the framework offers [bridging
functions](ReactiveCocoa/Swift/ObjectiveCBridging.swift) that can convert types
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

In RAC 3, “hot” signals are now solely represented by the
[`Signal`](ReactiveCocoa/Swift/Signal.swift) class, and “cold” signals have been
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

In RAC 3, “cold” signals are now solely represented by the
[`SignalProducer`](ReactiveCocoa/Swift/SignalProducer.swift) class, which
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
[parameterized](#parameterized-types) by the types they use. An action must
indicate the type of input it accepts, the type of output it produces, and
what kinds of errors can occur (if any). This eliminates a few classes of type
error, and clarifies intention.

Actions are also intended to be simpler overall than their predecessor. Unlike
commands, actions are not bound to or dependent upon the main thread, making it
easier to reason about when they can be executed and when they will generate
notifications. Actions also only support serial execution, because concurrent
execution was a rarely used feature of `RACCommand` that added significant
complexity to the interface and implementation.

Because actions are frequently used in conjunction with AppKit or UIKit, there
is also a `CocoaAction` class that erases the type parameters of an `Action`,
allowing it to be used from Objective-C.

As an example, an action can be wrapped and bound to `UIControl` like so:

```swift
self.cocoaAction = CocoaAction(underlyingAction)
self.button.addTarget(self.cocoaAction, action: self.cocoaAction.selector, forControlEvents: UIControlEvents.TouchUpInside)
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

In addition, because `-flattenMap:` is the easiest to use, it was often
incorrectly chosen even when concatenation or switching semantics are more
appropriate.

RAC 3 distills these concepts down into just two operators, named `join` and `joinMap`.
Both accept a “strategy” which determines how the producer-of-producers should
be integrated, which can be one of:

 * `.Merge`, which is equivalent to `-flatten` or `+merge:`
 * `.Concat`, which is equivalent to `-concat` or `+concat:`
 * `.Latest`, which is equivalent to `-switchToLatest`

This reduces the API surface area, and forces callers to consciously think about
which strategy is most appropriate for a given use.

For streams of exactly one value, calls to `-flattenMap:` can be replaced with
`joinMap(.Concat)`, which has the additional benefit of predictable behavior if
the input stream is refactored to have more values in the future.

## Minor changes
