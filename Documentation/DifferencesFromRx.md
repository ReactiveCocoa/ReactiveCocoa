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
