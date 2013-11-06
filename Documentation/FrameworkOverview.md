# Framework Overview

This document contains a high-level description of the different components
within the ReactiveCocoa framework, and an attempt to explain how they work
together and divide responsibilities. This is meant to be a starting point for
learning about new modules and finding more specific documentation.

For examples and help understanding how to use RAC, see the [README][] or
the [Design Guidelines][].

## Streams

A **stream**, represented by the [RACStream][] abstract class, is any series of
object values.

Values may be available immediately or in the future, but must be retrieved
sequentially. There is no way to retrieve the second value of a stream without
evaluating or waiting for the first value.

Streams are [monads][]. Among other things, this allows complex operations to be
built on a few basic primitives (`-bind:` in particular). [RACStream][] also
implements the equivalent of the [Monoid][] and [MonadZip][] typeclasses from
[Haskell][].

[RACStream][] isn't terribly useful on its own. Most streams are treated as
[signals](#signals) or [sequences](#sequences) instead.

## Signals

A **signal**, represented by the [RACSignal][] class, is a _push-driven_
[stream](#streams).

Signals generally represent data that will be delivered in the future. As work
is performed or data is received, values are _sent_ on the signal, which pushes
them out to any subscribers. Users must [subscribe](#subscription) to a signal
in order to access its values.

Signals send three different types of events to their subscribers:

 * The **next** event provides a new value from the stream. [RACStream][]
   methods only operate on events of this type. Unlike Cocoa collections, it is
   completely valid for a signal to include `nil`.
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
a [subject](#subjects) or a [promise](#promises).

### Subscription

A **subscriber** is anything that is waiting or capable of waiting for events
from a [signal](#signals). Within RAC, a subscriber is represented as any object
that conforms to the [RACSubscriber][] protocol.

A **subscription** is created through any call to
[-subscribeNext:error:completed:][RACSignal], or one of the corresponding
convenience methods. Technically, most [RACStream][] and
[RACSignal][RACSignal+Operations] operators create subscriptions as well, but
these intermediate subscriptions are usually an implementation detail.

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

RAC adds a `rac_action` property to many built-in AppKit and UIKit controls, to
make it easy to set up these behaviors automatically.

## Promises

A **promise**, implemented as the [RACPromise][] class, represents work that
should be performed (at most) once. This is useful for one-off tasks that should
never be repeated, like deleting a file on disk.

Promises can start _eagerly_ (immediately upon creation) or _lazily_ (only when
the results are needed), and cannot be canceled once they begin executing.

In RAC, promises have a symbiotic relationship with [signals](#signals). Signals
are used to deliver the results of a promise, and any signal can be converted
into a promise. Consequently, which one to use should be determined entirely by
the use case, and not by APIs.

## Sequences

A **sequence**, represented by the [RACSequence][] class, is a _pull-driven_
[stream](#streams).

Sequences are a kind of collection, similar in purpose to `NSArray`. Unlike
an array, the values in a sequence are evaluated _lazily_ (i.e., only when they
are needed) by default, potentially improving performance if only part of
a sequence is used. Just like Cocoa collections, sequences cannot contain `nil`.

Sequences are similar to [Clojure's sequences][seq] ([lazy-seq][] in particular), or
the [List][] type in [Haskell][].

RAC adds a `-rac_sequence` method to most of Cocoa's collection classes,
allowing them to be used as [RACSequences][RACSequence] instead.

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
a [stream](#streams):

 * **[RACTuple][]** is a small, constant-sized collection that can contain
   `nil` (represented by `RACTupleNil`). It is generally used to represent
   the combined values of multiple streams.
 * **[RACUnit][]** is a singleton "empty" value. It is used as a value in
   a stream for those times when more meaningful data doesn't exist.
 * **[RACEvent][]** represents any [signal event](#signals) as a single value.
   It is primarily used by the `-materialize` method of
   [RACSignal][RACSignal+Operations].

## Foundation Support

There are a number of categories that provide RAC-based bridges to standard
Foundation classes. They're not included as part of the framework proper in
order to keep the framework size down.

You can find them in [RACExtensions][]. To use them, simply add them directly to
your project as needed.

## Asynchronous Backtraces

Because RAC-based code often involves asynchronous work and queue-hopping, the
framework supports [capturing asynchronous backtraces][RACBacktrace] to make debugging
easier.

On OS X, backtraces can be automatically captured from any code, including
system libraries.

On iOS, only queue hops from within RAC and your project will be captured (but
the information is still valuable).

[Design Guidelines]: DesignGuidelines.md
[Futures and promises]: http://en.wikipedia.org/wiki/Futures_and_promises
[Haskell]: http://www.haskell.org
[lazy-seq]: http://clojure.github.com/clojure/clojure.core-api.html#clojure.core/lazy-seq
[List]: http://www.haskell.org/ghc/docs/latest/html/libraries/base-4.6.0.1/Data-List.html
[Memory Management]: MemoryManagement.md
[monads]: http://en.wikipedia.org/wiki/Monad_(functional_programming)
[Monoid]: http://www.haskell.org/ghc/docs/latest/html/libraries/base-4.6.0.1/Data-Monoid.html#t:Monoid
[MonadZip]: http://www.haskell.org/ghc/docs/latest/html/libraries/base-4.6.0.1/Control-Monad-Zip.html#t:MonadZip
[RACAction]: ../ReactiveCocoaFramework/ReactiveCocoa/RACAction.h
[RACBacktrace]: ../ReactiveCocoaFramework/ReactiveCocoa/RACBacktrace.h
[RACDisposable]: ../ReactiveCocoaFramework/ReactiveCocoa/RACDisposable.h
[RACEvent]: ../ReactiveCocoaFramework/ReactiveCocoa/RACEvent.h
[RACExtensions]: ../RACExtensions
[RACPromise]: ../ReactiveCocoaFramework/ReactiveCocoa/RACPromise.h
[RACScheduler]: ../ReactiveCocoaFramework/ReactiveCocoa/RACScheduler.h
[RACSequence]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSequence.h
[RACSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h
[RACStream]: ../ReactiveCocoaFramework/ReactiveCocoa/RACStream.h
[RACSubject]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubject.h
[RACSubscriber]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSubscriber.h
[RACTuple]: ../ReactiveCocoaFramework/ReactiveCocoa/RACTuple.h
[RACUnit]: ../ReactiveCocoaFramework/ReactiveCocoa/RACUnit.h
[README]: ../README.md
[seq]: http://clojure.org/sequences
