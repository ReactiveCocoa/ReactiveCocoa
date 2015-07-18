# ReactiveCocoa [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

ReactiveCocoa (RAC) is an Objective-C and Swift framework inspired by
[Functional Reactive
Programming](http://en.wikipedia.org/wiki/Functional_reactive_programming). It
provides APIs for composing and transforming **streams of values over time**.

 1. [Introduction](#introduction)
 1. [Example: online search](#example-online-search)
 1. [How does ReactiveCocoa relate to Rx?](#how-does-reactivecocoa-relate-to-rx)
 1. [Getting started](#getting-started)

If you’re already familiar with functional reactive programming or what
ReactiveCocoa is about, check out the [Documentation](Documentation) folder for more in-depth
information about how it all works. Then, dive straight into our [documentation
comments](ReactiveCocoa) for learning more about individual APIs.

If you have a question, please see if any discussions in our [GitHub
issues](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?q=is%3Aissue+label%3Aquestion+) or [Stack
Overflow](http://stackoverflow.com/questions/tagged/reactive-cocoa) have already
answered it. If not, please feel free to [file your
own](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/new)!

_Many thanks to [Rheinfabrik](http://www.rheinfabrik.de) for generously sponsoring the development of ReactiveCocoa 3!_

## Introduction

ReactiveCocoa is inspired by [functional reactive
programming](http://blog.maybeapps.com/post/42894317939/input-and-output).
Rather than using mutable variables which are replaced and modified in-place,
RAC offers “event streams,” represented by the `Signal` and `SignalProducer`
types, that send values over time.

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

## Example: online search

Let’s say you have a text field, and whenever the user types something into it,
you want to make a network request which searches for that query.

#### Observing text edits

The first step is to observe edits to the text field, using a RAC extension to
`UITextField` specifically for this purpose:

```swift
let searchStrings = textField.rac_textSignal()
    |> toSignalProducer()
    |> map { text in text as! String }
```

This gives us a [signal
producer](Documentation/FrameworkOverview.md#signal-producers) which sends
values of type `String`. _(The cast is [currently
necessary](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2182) to bridge
this extension method from Objective-C.)_

#### Making network requests

With each string, we want to execute a network request. Luckily, RAC offers an
`NSURLSession` extension for doing exactly that:

```swift
let searchResults = searchStrings
    |> flatMap(.Latest) { query in
        let URLRequest = self.searchRequestWithEscapedQuery(query)
        return NSURLSession.sharedSession().rac_dataWithRequest(URLRequest)
    }
    |> map { data, URLResponse in
        let string = String(data: data, encoding: NSUTF8StringEncoding)!
        return parseJSONResultsFromString(string)
    }
```

This has transformed our producer of `String`s into a producer of `Array`s
containing the search results.

Additionally, `flatMap(.Latest)` here ensures that _only one search_—the
latest—is allowed to be running. If the user types another character while the
network request is still in flight, it will be cancelled before starting a new
one. Just think of how much code that would take to do by hand!

#### Receiving the results

This won’t actually execute yet, because producers must be _started_ in order to
receive the results (which prevents doing work when the results are never used).
That’s easy enough:

```swift
searchResults.start(next: { results in
    println("Search results: \(results)")
}, error: { error in
    println("Error searching: \(error)")
})
```

Here, we watch for the `Next` and `Error`
[events](Documentation/FrameworkOverview.md#events), and just log to the
console. This could easily do something else instead, like update a table view
or a label on screen.

#### Throttling requests

Now, let’s say you only want to actually perform the search when the user pauses
typing, to minimize traffic.

ReactiveCocoa has a declarative `throttle` operator that we can apply to our
search strings:

```swift
let searchStrings = textField.rac_textSignal()
    |> toSignalProducer()
    |> map { text in text as! String }
    |> throttle(0.5, onScheduler: UIScheduler())
```

This prevents values from being sent less than 0.5 seconds apart, so the user
must stop editing for at least that long before we’ll use their search string.

To do this manually would require significant state, and end up much harder to
read! With ReactiveCocoa, we can use just one operator to incorporate _time_ into
our event stream.

## How does ReactiveCocoa relate to Rx?

TODO

## Getting started

ReactiveCocoa supports OS X 10.9+ and iOS 8.0+.

To add RAC to your application:

 1. Add the ReactiveCocoa repository as a
    [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) of your
    application’s repository.
 1. Run `script/bootstrap` from within the ReactiveCocoa folder.
 1. Drag and drop `ReactiveCocoa.xcodeproj` into your application’s Xcode
    project or workspace.
 1. On the “General” tab of your application target’s settings, add
    `ReactiveCocoa.framework` to the “Embedded Binaries” section.

Or, if you’re using [Carthage](https://github.com/Carthage/Carthage), simply add
ReactiveCocoa to your `Cartfile`:

```
github "ReactiveCocoa/ReactiveCocoa"
```

If you would prefer to use [CocoaPods](https://cocoapods.org), there are some
[unofficial podspecs](https://github.com/CocoaPods/Specs/tree/master/Specs/ReactiveCocoa) that have been generously contributed by third parties.
