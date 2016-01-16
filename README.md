![](Logo/header.png)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![GitHub release](https://img.shields.io/github/release/ReactiveCocoa/ReactiveCocoa.svg)](https://github.com/ReactiveCocoa/ReactiveCocoa/releases) ![Swift 2.1.1](https://img.shields.io/badge/Swift-2.1.1-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OS%20X%20%7C%20watchOS%20%7C%20tvOS%20-lightgrey.svg)

ReactiveCocoa (RAC) is a Cocoa framework inspired by [Functional Reactive Programming](https://en.wikipedia.org/wiki/Functional_reactive_programming). It provides APIs for composing and transforming **streams of values over time**.

 1. [Introduction](#introduction)
 1. [Example: online search](#example-online-search)
 1. [Objective-C and Swift](#objective-c-and-swift)
 1. [How does ReactiveCocoa relate to Rx?](#how-does-reactivecocoa-relate-to-rx)
 1. [Getting started](#getting-started)

If you’re already familiar with functional reactive programming or what
ReactiveCocoa is about, check out the [Documentation][] folder for more in-depth
information about how it all works. Then, dive straight into our [documentation
comments][Code] for learning more about individual APIs.

If you have a question, please see if any discussions in our [GitHub
issues](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?q=is%3Aissue+label%3Aquestion+) or [Stack
Overflow](http://stackoverflow.com/questions/tagged/reactive-cocoa) have already
answered it. If not, please feel free to [file your
own](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/new)!

#### Compatibility

This documents the RAC 4 (currently alpha) which targets Swift 2.x. For
Swift 1.2 support see the [RAC
3](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v3.0.0).

_Many thanks to [Rheinfabrik](http://www.rheinfabrik.de) for generously sponsoring the development of ReactiveCocoa 3!_

## Introduction

ReactiveCocoa is inspired by [functional reactive
programming](http://blog.maybeapps.com/post/42894317939/input-and-output).
Rather than using mutable variables which are replaced and modified in-place,
RAC offers “event streams,” represented by the [`Signal`][Signals] and
[`SignalProducer`][Signal producers] types, that send values over time.

Event streams unify all of Cocoa’s common patterns for asynchrony and event
handling, including:

 * Delegate methods
 * Callback blocks
 * `NSNotification`s
 * Control actions and responder chain events
 * [Futures and promises](https://en.wikipedia.org/wiki/Futures_and_promises)
 * [Key-value observing](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) (KVO)

Because all of these different mechanisms can be represented in the _same_ way,
it’s easy to declaratively chain and combine them together, with less spaghetti
code and state to bridge the gap.

For more information about the concepts in ReactiveCocoa, see the [Framework
Overview][].

## Example: online search

Let’s say you have a text field, and whenever the user types something into it,
you want to make a network request which searches for that query.

#### Observing text edits

The first step is to observe edits to the text field, using a RAC extension to
`UITextField` specifically for this purpose:

```swift
let searchStrings = textField.rac_textSignal()
    .toSignalProducer()
    .map { text in text as! String }
```

This gives us a [signal producer][Signal producers] which sends
values of type `String`. _(The cast is [currently
necessary](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2182) to bridge
this extension method from Objective-C.)_

#### Making network requests

With each string, we want to execute a network request. Luckily, RAC offers an
`NSURLSession` extension for doing exactly that:

```swift
let searchResults = searchStrings
    .flatMap(.Latest) { (query: String) -> SignalProducer<(NSData, NSURLResponse), NSError> in
        let URLRequest = self.searchRequestWithEscapedQuery(query)
        return NSURLSession.sharedSession().rac_dataWithRequest(URLRequest)
    }
    .map { (data, URLResponse) -> String in
        let string = String(data: data, encoding: NSUTF8StringEncoding)!
        return self.parseJSONResultsFromString(string)
    }
    .observeOn(UIScheduler())
```

This has transformed our producer of `String`s into a producer of `Array`s
containing the search results, which will be forwarded on the main thread
(thanks to the [`UIScheduler`][Schedulers]).

Additionally, [`flatMap(.Latest)`][flatMapLatest] here ensures that _only one search_—the
latest—is allowed to be running. If the user types another character while the
network request is still in flight, it will be cancelled before starting a new
one. Just think of how much code that would take to do by hand!

#### Receiving the results

This won’t actually execute yet, because producers must be _started_ in order to
receive the results (which prevents doing work when the results are never used).
That’s easy enough:

```swift
searchResults.startWithNext { results in
    print("Search results: \(results)")
}
```

Here, we watch for the `Next` [event][Events], which contains our results, and
just log them to the console. This could easily do something else instead, like
update a table view or a label on screen.

#### Handling failures

In this example so far, any network error will generate a `Failed`
[event][Events], which will terminate the event stream. Unfortunately, this
means that future queries won’t even be attempted.

To remedy this, we need to decide what to do with failures that occur. The
quickest solution would be to log them, then ignore them:

```swift
    .flatMap(.Latest) { (query: String) -> SignalProducer<(NSData, NSURLResponse), NSError> in
        let URLRequest = self.searchRequestWithEscapedQuery(query)

        return NSURLSession.sharedSession()
            .rac_dataWithRequest(URLRequest)
            .flatMapError { error in
                print("Network error occurred: \(error)")
                return SignalProducer.empty
            }
    }
```

By replacing failures with the `empty` event stream, we’re able to effectively
ignore them.

However, it’s probably more appropriate to retry at least a couple of times
before giving up. Conveniently, there’s a [`retry`][retry] operator to do exactly that!

Our improved `searchResults` producer might look like this:

```swift
let searchResults = searchStrings
    .flatMap(.Latest) { (query: String) -> SignalProducer<(NSData, NSURLResponse), NSError> in
        let URLRequest = self.searchRequestWithEscapedQuery(query)

        return NSURLSession.sharedSession()
            .rac_dataWithRequest(URLRequest)
            .retry(2)
            .flatMapError { error in
                print("Network error occurred: \(error)")
                return SignalProducer.empty
            }
    }
    .map { (data, URLResponse) -> String in
        let string = String(data: data, encoding: NSUTF8StringEncoding)!
        return self.parseJSONResultsFromString(string)
    }
    .observeOn(UIScheduler())
```

#### Throttling requests

Now, let’s say you only want to actually perform the search when the user pauses
typing, to minimize traffic.

ReactiveCocoa has a declarative `throttle` operator that we can apply to our
search strings:

```swift
let searchStrings = textField.rac_textSignal()
    .toSignalProducer()
    .map { text in text as! String }
    .throttle(0.5, onScheduler: QueueScheduler.mainQueueScheduler)
```

This prevents values from being sent less than 0.5 seconds apart, so the user
must stop editing for at least that long before we’ll use their search string.

To do this manually would require significant state, and end up much harder to
read! With ReactiveCocoa, we can use just one operator to incorporate _time_ into
our event stream.

## Objective-C and Swift

Although ReactiveCocoa was started as an Objective-C framework, as of [version
3.0][CHANGELOG], all major feature development is concentrated on the [Swift API][].

RAC’s [Objective-C API][] and Swift API are entirely separate, but there is
a [bridge][Objective-C Bridging] to convert between the two. This
is mostly meant as a compatibility layer for older ReactiveCocoa projects, or to
use Cocoa extensions which haven’t been added to the Swift API yet.

The Objective-C API will continue to exist and be supported for the foreseeable
future, but it won’t receive many improvements. For more information about using
this API, please consult our [legacy documentation][].

**We highly recommend that all new projects use the Swift API.**

## How does ReactiveCocoa relate to Rx?

ReactiveCocoa was originally inspired, and therefore heavily influenced, by
Microsoft’s [Reactive
Extensions](https://msdn.microsoft.com/en-us/data/gg577609.aspx) (Rx) library. There are many ports of Rx, including [RxSwift](https://github.com/ReactiveX/RxSwift), but ReactiveCocoa is _intentionally_ not a direct port.

**Where RAC differs from Rx**, it is usually to:

 * Create a simpler API
 * Address common sources of confusion
 * More closely match Cocoa conventions

The following are some of the concrete differences, along with their rationales.

### Naming

In most versions of Rx, Streams over time are known as `Observable`s, which
parallels the `Enumerable` type in .NET. Additionally, most operations in Rx.NET
borrow names from [LINQ](https://msdn.microsoft.com/en-us/library/bb397926.aspx),
which uses terms reminiscent of relational databases, like `Select` and `Where`.

**RAC is focused on matching Swift naming first and foremost**, with terms like
`map` and `filter` instead. Other naming differences are typically inspired by
significantly better alternatives from [Haskell](https://www.haskell.org) or
[Elm](http://elm-lang.org) (which is the primary source for the “signal”
terminology).

### Signals and Signal Producers (“hot” and “cold” observables)

One of the most confusing aspects of Rx is that of [“hot”, “cold”, and “warm”
observables](http://www.introtorx.com/content/v1.0.10621.0/14_HotAndColdObservables.html) (event streams).

In short, given just a method or function declaration like this, in C#:

```csharp
IObservable<string> Search(string query)
```

… it is **impossible to tell** whether subscribing to (observing) that
`IObservable` will involve side effects. If it _does_ involve side effects, it’s
also impossible to tell whether _each subscription_ has a side effect, or if only
the first one does.

This example is contrived, but it demonstrates **a real, pervasive problem**
that makes it extremely hard to understand Rx code (and pre-3.0 ReactiveCocoa
code) at a glance.

[ReactiveCocoa 3.0][CHANGELOG] has solved this problem by distinguishing side
effects with the separate [`Signal`][Signals] and [`SignalProducer`][Signal producers] types. Although this
means there’s another type to learn about, it improves code clarity and helps
communicates intent much better.

In other words, **ReactiveCocoa’s changes here are [simple, not
easy](http://www.infoq.com/presentations/Simple-Made-Easy)**.

### Typed errors

When [signals][] and [signal producers][] are allowed to [fail][Events] in ReactiveCocoa,
the kind of error must be specified in the type system. For example,
`Signal<Int, NSError>` is a signal of integer values that may fail with an error
of type `NSError`.

More importantly, RAC allows the special type `NoError` to be used instead,
which _statically guarantees_ that an event stream is not allowed to send a
failure. **This eliminates many bugs caused by unexpected failure events.**

In Rx systems with types, event streams only specify the type of their
values—not the type of their errors—so this sort of guarantee is impossible.

### UI programming

Rx is basically agnostic as to how it’s used. Although UI programming with Rx is
very common, it has few features tailored to that particular case.

RAC takes a lot of inspiration from [ReactiveUI](http://reactiveui.net/),
including the basis for [Actions][].

Unlike ReactiveUI, which unfortunately cannot directly change Rx to make it more
friendly for UI programming, **ReactiveCocoa has been improved many times
specifically for this purpose**—even when it means diverging further from Rx.

## Getting started

ReactiveCocoa supports `OS X 10.9+`, `iOS 8.0+`, `watchOS 2.0`, and `tvOS 9.0`.

To add RAC to your application:

 1. Add the ReactiveCocoa repository as a
    [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) of your
    application’s repository.
 1. Run `script/bootstrap` from within the ReactiveCocoa folder.
 1. Drag and drop `ReactiveCocoa.xcodeproj` and `Carthage/Checkouts/Result/Result.xcodeproj`
    into your application’s Xcode project or workspace.
 1. On the “General” tab of your application target’s settings, add
    `ReactiveCocoa.framework` and `Result.framework` to the “Embedded Binaries” section.
 1. If your application target does not contain Swift code at all, you should also
    set the `EMBEDDED_CONTENT_CONTAINS_SWIFT` build setting to “Yes”.

Or, if you’re using [Carthage](https://github.com/Carthage/Carthage), simply add
ReactiveCocoa to your `Cartfile`:

```
github "ReactiveCocoa/ReactiveCocoa"
```

If you would prefer to use [CocoaPods](https://cocoapods.org), there are some
[unofficial podspecs](https://github.com/CocoaPods/Specs/tree/master/Specs/ReactiveCocoa)
that have been generously contributed by third parties.

Once you’ve set up your project, check out the [Framework Overview][] for
a tour of ReactiveCocoa’s concepts, and the [Basic Operators][] for some
introductory examples of using it.


[Actions]: Documentation/FrameworkOverview.md#actions
[Basic Operators]: Documentation/BasicOperators.md
[CHANGELOG]: CHANGELOG.md
[Code]: ReactiveCocoa
[Documentation]: Documentation
[Events]: Documentation/FrameworkOverview.md#events
[Framework Overview]: Documentation/FrameworkOverview.md
[Legacy Documentation]: Documentation/Legacy
[Objective-C API]: ReactiveCocoa/Objective-C
[Objective-C Bridging]: Documentation/ObjectiveCBridging.md
[Schedulers]: Documentation/FrameworkOverview.md#schedulers
[Signal producers]: Documentation/FrameworkOverview.md#signal-producers
[Signals]: Documentation/FrameworkOverview.md#signals
[Swift API]: ReactiveCocoa/Swift
[flatMapLatest]: Documentation/BasicOperators.md#switching-to-the-latest
[retry]: Documentation/BasicOperators.md#retrying
