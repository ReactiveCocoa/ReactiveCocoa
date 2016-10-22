![](Logo/header.png)
##### Reactive extensions to Cocoa frameworks, built on top of [ReactiveSwift][].

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage) [![CocoaPods compatible](https://img.shields.io/cocoapods/v/ReactiveCocoa.svg)](#cocoapods) [![GitHub release](https://img.shields.io/github/release/ReactiveCocoa/ReactiveCocoa.svg)](https://github.com/ReactiveCocoa/ReactiveCocoa/releases) ![Swift 3.0.x](https://img.shields.io/badge/Swift-3.0.x-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OS%20X%20%7C%20watchOS%20%7C%20tvOS%20-lightgrey.svg)

[&raquo; Looking for the Objective-C API?](#objective-c-swift-and-the-reactivecocoa-family)

## Introduction

__ReactiveCocoa__ wraps various aspects of Cocoa frameworks with the declarative primitives from [ReactiveSwift](). Let's go through a few core aspects of ReactiveCocoa:

1. **Unidirectional UI bindings**

	You may establish bindings from any streams of values to the `BindingTarget`s
	exposed by the UI components.

	```swift
	nameLabel.text <~ person.name
	```

1. **Controls and User Interactions**

	You may observe many kinds of user interactions as streams of values. For
	example, UI controls expose signals that send user initiated
	changes in its state.
	```swift
	perferences.allowsCookies <~ cookieMonsterView.toggle.isOnValues 
	```

1. **Expressive, safe key path observation**

	You may easily obtain a stream of values for a certain key path, without the
	need to deal with the obscure KVO API.
	```swift
	let producer = object.reactive.values(forKeyPath: #keyPath(key))
	```

1. **Object deinitialization**

	You may couple resources to or compose signal with the `Lifetime` of every
  `NSObject`.
	```swift
	NotificationCenter.default.reactive
		.notifications(forName: .MyNotification)
		.take(until: self.reactive.lifetime)
	```

1. **Method call interception**

	You may ask to intercept a particular method, and get notified after it is
	called.
	```swift
	let appearing = object.reactive.trigger(for: #selector(viewWillAppear(_:)))
	```

But there are still more to be discovered, and more to be introduced. Read our in-code documentations and release notes to
find out more.


#### On ReactiveSwift
ReactiveSwift is inspired by [functional reactive
																	programming](https://joshaber.github.io/2013/02/11/input-and-output/).


Rather than using mutable variables which are replaced and modified in-place,
ReactiveSwift offers two core primitives, [`Signal`][Signals] and [`SignalProducer`][Signal producers], that derive from the grand concept of ___stream of values over time___.

It is flexible enough to uniformly represent generic patterns and common Cocoa patterns that are fundementally an act of observation. e.g. _Callbacks_, _Futures_, _Promises_, _Notifications_, _Target-Action_, _Key Value Observing_ (KVO), etc.

With states all being represented reactively, it is easy to declaratively chain and compose the streams of values together, with less spaghetti code and state to bridge the gap.

For more information about the core primitives, see [ReactiveSwift]().

## Getting started

ReactiveCocoa supports macOS 10.9+, iOS 8.0+, watchOS 2.0+, and tvOS 9.0+.

#### Carthage

If you are using [Carthage](https://github.com/Carthage/Carthage) to manage your dependency, simply add
ReactiveCocoa to your `Cartfile`:

```
github "ReactiveCocoa/ReactiveCocoa"
```

If you use Carthage to build your dependencies, make sure you have added `ReactiveCocoa.framework`, `ReactiveSwift.framework`, and `Result.framework` to the "_Linked Frameworks and Libraries_" section of your target, and have included them in your Carthage framework copying build phase.

#### CocoaPods

If you are using [CocoaPods](https://cocoapods.org/) to manage your dependency, simply add
ReactiveCocoa to your `Podfile`:

```
pod 'ReactiveCocoa', :git => 'https://github.com/ReactiveCocoa/ReactiveCocoa.git'
```

#### Git submodule

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


## Objective-C, Swift and the ReactiveCocoa family

Starting with [version 5.0][CHANGELOG], ReactiveCocoa primarily focuses on providing reactive extensions to Cocoa frameworks in Swift. In other words:

1. The core Swift API - which provides FRP inspired primitives - had been spun off as [ReactiveSwift][].

2. The legacy Objective-C API had been spun off as [ReactiveObjC][].

3. The bridge between the core Swift API and the legacy Objective-C API is now hosted in ([ReactiveObjCBridge][]), which is mostly meant as a compatibility layer for older ReactiveCocoa projects.

The Objective-C API will continue to be maintained and supported in the foreseeable future. But given the maturity of the framework and the language, non-trivial changes are not expected. Please visit [ReactiveObjC][] for more information.

**We highly recommend all Swift projects using the Swift API.**

## Have a question?
If you need any help, please visit our [GitHub issues](https://github.com/ReactiveCocoa/ReactiveCocoa/issues?q=is%3Aissue+label%3Aquestion+) or [Stack Overflow](http://stackoverflow.com/questions/tagged/reactive-cocoa). Feel free to file an issue if you do not manage to find any solution from the archives.

## Using Swift 2.x?
See [ReactiveCocoa
4.x](https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v4.0.0) for legacy Swift support.


[ReactiveSwift]: https://github.com/ReactiveCocoa/ReactiveSwift
[ReactiveObjC]: https://github.com/ReactiveCocoa/ReactiveObjC
[ReactiveObjCBridge]: https://github.com/ReactiveCocoa/ReactiveObjCBridge
[Actions]: Documentation/FrameworkOverview.md#actions
[Basic Operators]: Documentation/BasicOperators.md
[CHANGELOG]: CHANGELOG.md
[Code]: ReactiveCocoa
[Documentation]: Documentation
[Framework Overview]: Documentation/FrameworkOverview.md
[Legacy Documentation]: https://github.com/ReactiveCocoa/ReactiveObjC/blob/master/Documentation/
[Signal producers]: Documentation/FrameworkOverview.md#signal-producers
[Signals]: Documentation/FrameworkOverview.md#signals
[Swift API]: ReactiveCocoa/Swift
