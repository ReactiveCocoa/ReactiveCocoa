# Differences from Rx

ReactiveCocoa (RAC) is significantly inspired by .NET's [Reactive
Extensions](http://msdn.microsoft.com/en-us/data/gg577609.aspx) (Rx), but it is not
a direct port. Some concepts or interfaces presented in RAC may be initially
confusing to a developer already familiar with Rx, but it's usually possible to
express the same algorithms.

Some of the differences, like the naming of methods and classes, are meant to
keep RAC in line with existing Cocoa conventions. Other differences are intended
as improvements over Rx, or may be inspired by other functional reactive
programming paradigms (like the [Elm programming
language](http://elm-lang.org)).

Here, we'll attempt to document the high-level differences between RAC and Rx.

## Interfaces

RAC does not offer protocols that correspond to the `IEnumerable` and
`IObservable` interfaces in .NET. Instead, the functionality is covered by three
main classes:

 * **[RACStream](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACStream.h)**
   is an abstract class that implements stream operations using a few basic
   primitives. The equivalents to generic LINQ operators can generally be found
   on this class.
 * **[RACSignal](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACSignal.h)**
   is a concrete subclass of `RACStream` that implements a _push-driven_ stream,
   much like `IObservable`. Time-based operators, or methods dealing with the
   `completed` and `error` events, can be found on this class or in the
   [RACSignal+Operations](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACSignal%2BOperations.h)
   category upon it.
 * **[RACSequence](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoaFramework/ReactiveCocoa/RACSequence.h)**
   is a concrete subclass of `RACStream` that implements a _pull-driven_ stream,
   much like `IEnumerable`.

## Names of Stream Operations

RAC generally uses LINQ-style naming for its stream methods. Most of the
exceptions are inspired by significantly better alternatives in Haskell or Elm.

Notable differences include:

 * `-map:` instead of `Select`
 * `-filter:` instead of `Where`
 * `-flatten` instead of `Merge`
 * `-flattenMap:` instead of `SelectMany`

LINQ operators that go by different names in RAC (but behave more or less
equivalently) will be referenced from method documentation, like so:

```objc
// Maps `block` across the values in the receiver.
//
// This corresponds to the `Select` method in Rx.
//
// Returns a new stream with the mapped values.
- (instancetype)map:(id (^)(id value))block;
```
