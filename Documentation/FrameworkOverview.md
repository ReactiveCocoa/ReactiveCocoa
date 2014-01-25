# Framework Overview

This document contains a high-level description of the different components
within the ReactiveCocoa framework, and an attempt to explain how they work
together and divide responsibilities. This is meant to be a starting point for
learning about new modules and finding more specific documentation.

For examples and help understanding how to use RAC, see the [README][] or
the [Design Guidelines][].

## Signals

A **signal**, represented by the [RACSignal][] class, is a _push-driven_
stream.

Signals generally represent data that will be delivered in the future. As work
is performed or data is received, values are _sent_ on the signal, which pushes
them out to any subscribers. Users must [subscribe](#subscription) to a signal
in order to access its values.

Signals send three different types of events to their subscribers:

 * The **next** event provides a new value from the stream. Unlike Cocoa
   collections, it is completely valid for a signal to include `nil`.
 * The **error** event indicates that an error occurred before the signal could
   finish. The event may include an `NSError` object that indicates what went
   wrong. Errors must be handled specially – they are not included in the
   stream's values.
 * The **completed** event indicates that the signal finished successfully, and
   that no more values will be added to the stream. Completion must be handled
   specially – it is not included in the stream of values.

The lifetime of a signal consists of any number of `next` events, followed by
one `error` or `completed` event (but not both).

Signals are _cold_ by default, meaning that they start doing work _each_ time
a new subscription is added. This behavior is usually desirable, because it
means that data will be freshly recalculated for each subscriber, but it can be
problematic if the signal has side effects or the work is expensive (for
example, sending a network request).

To share the values of a signal without duplicating its side effects, use
a [subject](#subjects).

### Subscription

A **subscriber** is anything that is waiting or capable of waiting for events
from a [signal](#signals). Within RAC, a subscriber is represented as any object
that conforms to the [RACSubscriber][] protocol.

A **subscription** is created through any call to
[-subscribeNext:error:completed:][RACSignal], or one of the corresponding
convenience methods. Technically, most [operators][RACSignal+Operations] create
subscriptions as well, but these intermediate subscriptions are usually an
implementation detail.

Subscriptions [retain their signals][Memory Management], and are automatically
disposed of when the signal completes or errors. Subscriptions can also be
[disposed of manually](#disposables).

### Subjects

A **subject**, represented by the [RACSubject][] class, is a [signal](#signals)
that can be manually controlled.

Subjects can be thought of as the "mutable" variant of a signal, much like
`NSMutableArray` is for `NSArray`. They are extremely useful for bridging
non-RAC code into the world of signals.

For example, instead of handling application logic in block callbacks, the
blocks can simply send events to a shared subject instead. The subject can then
be returned as a [RACSignal][], hiding the implementation detail of the
callbacks.

Subjects can also be used to share a signal's values without duplicating its
side effects. Unlike signals (which start off "cold"), subjects are _hot_,
meaning they don't perform any side effects upon [subscription](#subscription).

Therefore, if multiple parties are interested in a signal's values — but its side
effects shouldn't be repeated — you can forward the events to a subject (using
[-subscribe:][RACSignal]), and have everything subscribe to the subject instead.

## Actions

An **action**, represented by the [RACAction][] class, subscribes to a signal in
response to some UI action, like a button being clicked. This makes it easy to
perform side-effecting work as the user interacts with the app.

Actions can also be automatically disabled based on a signal, and this disabled
state can be represented in a UI by disabling any controls associated with the
action.

RAC adds a `rac_action` property to many built-in AppKit and UIKit controls, to
make it easy to set up these behaviors automatically.

## Disposables

The **[RACDisposable][]** class is used for cancellation and resource cleanup.

Disposables are most commonly used to unsubscribe from a [signal](#signals).
When a [subscription](#subscription) is disposed, the corresponding subscriber
will not receive _any_ further events from the signal. Additionally, any work
associated with the subscription (background processing, network requests, etc.)
will be cancelled, since the results are no longer needed.

For more information about cancellation, see the RAC [Design Guidelines][].

## Schedulers

A **scheduler**, represented by the [RACScheduler][] class, is a serial
execution queue for [signals](#signals) to perform work or deliver their results upon.

Schedulers are similar to Grand Central Dispatch queues, but schedulers support
cancellation (via [disposables](#disposables)), and always execute serially.
With the exception of the [+immediateScheduler][RACScheduler], schedulers do not
offer synchronous execution. This helps avoid deadlocks, and encourages the use
of [signal operators][RACSignal+Operations] instead of blocking work.

[RACScheduler][] is also somewhat similar to `NSOperationQueue`, but schedulers
do not allow tasks to be reordered or depend on one another.

## Value types

RAC offers a few miscellaneous classes for conveniently representing values in
a [signal](#signals):

 * **[RACTuple][]** is a small, constant-sized collection that can contain
   `nil` (represented by `RACTupleNil`). It is generally used to represent
   the combined values of multiple signals.
 * **[RACUnit][]** is a singleton "empty" value. It is used as a value in
   a signal for those times when more meaningful data doesn't exist.
 * **[RACEvent][]** represents any signal event as a single value.
   It is primarily used by the `-materialize` method of
   [RACSignal][RACSignal+Operations].

## Asynchronous Backtraces

Because RAC-based code often involves asynchronous work and queue-hopping, the
framework supports [capturing asynchronous backtraces][RACBacktrace] to make debugging
easier.

On OS X, backtraces can be automatically captured from any code, including
system libraries.

On iOS, only queue hops from within RAC and your project will be captured (but
the information is still valuable).

[Design Guidelines]: DesignGuidelines.md
[Memory Management]: MemoryManagement.md
[RACAction]: ../ReactiveCocoaFramework/ReactiveCocoa/RACAction.h
[RACBacktrace]: ../ReactiveCocoaFramework/ReactiveCocoa/RACBacktrace.h
[RACDisposable]: ../ReactiveCocoaFramework/ReactiveCocoa/RACDisposable.h
[RACEvent]: ../ReactiveCocoaFramework/ReactiveCocoa/RACEvent.h
[RACScheduler]: ../ReactiveCocoaFramework/ReactiveCocoa/RACScheduler.h
[RACSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h
[RACSubject]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubject.h
[RACSubscriber]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubscriber.h
[RACTuple]: ../ReactiveCocoaFramework/ReactiveCocoa/RACTuple.h
[RACUnit]: ../ReactiveCocoaFramework/ReactiveCocoa/RACUnit.h
[README]: ../README.md
