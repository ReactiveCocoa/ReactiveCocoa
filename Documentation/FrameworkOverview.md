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
