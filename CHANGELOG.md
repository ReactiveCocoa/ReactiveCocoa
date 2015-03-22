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

 1. [Parameterized types](#)
 1. [Interrupted event](#)
 1. [Objective-C bridging](#)

**[Replacements](#replacements)**

 1. [Hot signals are now Signals](#)
 1. [Cold signals are now SignalProducers](#)
 1. [Commands are now Actions](#)
 1. [Using PropertyType instead of RACObserve and RAC](#)
 1. [Using Signal.pipe instead of RACSubject](#)
 1. [Using SignalProducer.buffer instead of replaying](#)
 1. [Using startWithSignal instead of multicasting](#)

**[Minor changes](#minor-changes)**

 1. [Disposable changes](#)
 1. [Scheduler changes](#)

## Additions

## Replacements

## Minor changes
