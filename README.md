![](Logo/header.png)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![GitHub release](https://img.shields.io/github/release/ReactiveCocoa/ReactiveCocoa.svg)](https://github.com/ReactiveCocoa/ReactiveCocoa/releases) ![Swift 3.0.x](https://img.shields.io/badge/Swift-3.0.x-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OS%20X%20%7C%20watchOS%20%7C%20tvOS%20-lightgrey.svg)

ReactiveCocoa (RAC) is a Cocoa framework built on top of [ReactiveSwift][]. It
provides APIs for using ReactiveSwift with Apple's Cocoa frameworks.

 1. [Introduction](#introduction)
 1. [Objective-C and Swift](#objective-c-and-swift)
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

This documents the RAC 5 which targets `Swift 3.0.x`. For `Swift 2.x` support see [RAC
4](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v4.0.0).

## Introduction

ReactiveCocoa is inspired by [functional reactive
programming](https://joshaber.github.io/2013/02/11/input-and-output/).
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

For more information about the concepts in ReactiveCocoa, see [ReactiveSwift][].

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

## Getting started

ReactiveCocoa supports `OS X 10.9+`, `iOS 8.0+`, `watchOS 2.0`, and `tvOS 9.0`.

To add RAC to your application:

 1. Add the ReactiveCocoa repository as a
    [submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) of your
    application’s repository.
 1. Run `git submodule update --init --recursive` from within the ReactiveCocoa folder.
 1. Drag and drop `ReactiveCocoa.xcodeproj`,
    `Carthage/Checkouts/ReactiveSwift/ReactiveSwift.xcodeproj`, and
    `Carthage/Checkouts/Result/Result.xcodeproj` into your application’s Xcode
    project or workspace.
 1. On the “General” tab of your application target’s settings, add
    `ReactiveCocoa.framework`, `ReactiveSwift.framework`, and `Result.framework`
    to the “Embedded Binaries” section.
 1. If your application target does not contain Swift code at all, you should also
    set the `EMBEDDED_CONTENT_CONTAINS_SWIFT` build setting to “Yes”.

Or, if you’re using [Carthage](https://github.com/Carthage/Carthage), simply add
ReactiveCocoa to your `Cartfile`:

```
github "ReactiveCocoa/ReactiveCocoa"
```
Make sure to add `ReactiveCocoa.framework`, `ReactiveSwift`, and `Result.framework` to "Linked Frameworks and Libraries" and "copy-frameworks" Build Phases.

If you would prefer to use [CocoaPods](https://cocoapods.org), there are some
[unofficial podspecs](https://github.com/CocoaPods/Specs/tree/master/Specs/ReactiveCocoa)
that have been generously contributed by third parties.

Once you’ve set up your project, check out the [Framework Overview][] for
a tour of ReactiveCocoa’s concepts, and the [Basic Operators][] for some
introductory examples of using it.

[ReactiveSwift]: https://github.com/ReactiveCocoa/ReactiveSwift
[Actions]: Documentation/FrameworkOverview.md#actions
[Basic Operators]: Documentation/BasicOperators.md
[CHANGELOG]: CHANGELOG.md
[Code]: ReactiveCocoa
[Documentation]: Documentation
[Framework Overview]: Documentation/FrameworkOverview.md
[Legacy Documentation]: Documentation/Legacy
[Objective-C API]: ReactiveCocoa/Objective-C
[Objective-C Bridging]: Documentation/ObjectiveCBridging.md
[Signal producers]: Documentation/FrameworkOverview.md#signal-producers
[Signals]: Documentation/FrameworkOverview.md#signals
[Swift API]: ReactiveCocoa/Swift
