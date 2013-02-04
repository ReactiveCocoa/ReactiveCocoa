# Framework Overview

This document contains a high-level description of the different components
within the ReactiveCocoa framework, and an attempt to explain how they work
together and divide responsibilities. This is meant to be a starting point for
learning about new modules and finding more specific documentation.

For examples and understanding how to use RAC, see the [README](../README.md) or
the [Design Guidelines](DesignGuidelines.md).

## Streams

A **stream**, represented by the [RACStream][] abstract class, is any series of
object values.

Values may be available immediately or in the future, but must be retrieved
sequentially. There is no way to retrieve the second value of a stream without
evaluating or waiting for the first value.

Streams are
[monads](http://en.wikipedia.org/wiki/Monad_(functional_programming)), which,
among other things, allows complex operations to be built on a few basic
primitives (of which `-[RACStream bind:]` is the most notable). For anyone
familiar with Haskell, [RACStream][] also implements the equivalent of the
[MonadPlus](http://www.haskell.org/ghc/docs/latest/html/libraries/base-4.6.0.1/Control-Monad.html#t:MonadPlus)
and
[MonadZip](http://www.haskell.org/ghc/docs/latest/html/libraries/base-4.6.0.1/Control-Monad-Zip.html#t:MonadZip)
typeclasses.

[RACStream][] isn't terribly useful on its own. Most streams are treated as
[signals](#Signals) or [sequences](#Sequences) instead.

### Signals

A **signal**, represented by the [RACSignal][] class, is a _push-based_ stream.

Signals generally represent an asynchronous computation or data request. As work
is performed or data is received, values are _sent on_ the signal, which pushes
them out to any subscribers. Users must _subscribe_ to a signal in order to
access its values.

Signals send three different types of events to their subscribers:

 * The **next** event provides a new value from the stream. [RACStream][]
   methods only operate on events of this type.
 * The **error** event indicates that an error occurred before the signal could
   finish. Errors must be handled specially – they are not included in the
   stream's values.
 * The **completed** event indicates that the signal finished successfully, and
   that no more values will be added to the stream. Completion must be handled
   specially – it is not included in the stream of values.

Thus, the lifetime of a signal consists of any number of `next` events, followed
by one `error` or `completed` event (but not both).

#### Subscribers
#### Disposables
#### Subjects
#### Commands

### Sequences

## Schedulers

## Value types

[RACSequence]: [../ReactiveCocoaFramework/ReactiveCocoa/RACSequence.h]
[RACSignal]: [../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h]
[RACSignal+Operations]: [../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h]
[RACStream]: [../ReactiveCocoaFramework/ReactiveCocoa/RACStream.h]
