# Design Guidelines

This document contains guidelines for projects that want to make use of
ReactiveCocoa. The content here is heavily inspired by the [Rx Design
Guidelines](http://blogs.msdn.com/b/rxteam/archive/2010/10/28/rx-design-guidelines.aspx).

## When to use RAC
### Handling asynchronous or event-driven data sources
### Chaining dependent operations
### Parallelizing independent work
### Simplifying collection transformations

## The RACSequence contract
### Evaluation occurs lazily by default
### Evaluation blocks the caller
### Side effects occur only once

## The RACSignal contract
### Signal events are serialized
### Event delivery may occur on any thread by default
### Errors are propagated immediately
### Side effects occur for each subscription
### Subscriptions are automatically disposed upon completion or error
### Outstanding work is cancelled on disposal
### Resources are cleaned up on disposal

## Best practices
### Use the same type for all the values of a stream
### Avoid retaining streams and disposables directly
### Process only as much of a stream as you need
### Deliver signal results onto a known scheduler
### Switch schedulers in as few places as possible
### Make side effects explicit
### Share the side effects of a signal by multicasting

## Implementing new operators
### Prefer building on RACStream methods
### Compose existing operators when possible
### Avoid introducing concurrency
### Cancel work and clean up all resources in a disposable
### Do not block in an operator
### Avoid stack overflow from deep recursion

[Memory Management]: MemoryManagement.md
[RACDisposable]: ../ReactiveCocoaFramework/ReactiveCocoa/RACDisposable.h
[RACEvent]: ../ReactiveCocoaFramework/ReactiveCocoa/RACEvent.h
[RACScheduler]: ../ReactiveCocoaFramework/ReactiveCocoa/RACScheduler.h
[RACSequence]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSequence.h
[RACSignal]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h
[RACSignal+Operations]: ../ReactiveCocoaFramework/ReactiveCocoa/RACSignal+Operations.h
