![](Logo/header.png)
#### Reactive extensions to Cocoa frameworks, built on top of [ReactiveSwift][].

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage) [![CocoaPods compatible](https://img.shields.io/cocoapods/v/ReactiveCocoa.svg)](#cocoapods) [![GitHub release](https://img.shields.io/github/release/ReactiveCocoa/ReactiveCocoa.svg)](https://github.com/ReactiveCocoa/ReactiveCocoa/releases) ![Swift 3.0.x](https://img.shields.io/badge/Swift-3.0.x-orange.svg) ![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20OS%20X%20%7C%20watchOS%20%7C%20tvOS%20-lightgrey.svg)

[&raquo; Looking for the Objective-C API?](#objective-c-swift-and-the-reactivecocoa-family)

## Introduction

__ReactiveCocoa__ wraps various aspects of Cocoa frameworks with the declarative primitives from [ReactiveSwift](). Let's go through a few core aspects of ReactiveCocoa:

1. **UI Bindings**

	UI components exposes `BindingTarget`s, which accept bindings from any
	kind of streams of values via the `<~` operator.

	```swift
	// Bind the `name` property of `person` to the text value of an `UILabel`.
	nameLabel.text <~ person.name
	```

1. **Controls and User Interactions**

	Interactive UI components expose `Signal`s for control events
	and updates in the control value upon user interactions.
	
	A selected set of controls provide a convenience, expressive binding
	API for `Action`s.
	
	
	```swift
	// Update `allowsCookies` whenever the toggle is flipped.
	perferences.allowsCookies <~ toggle.reactive.isOnValues 
	
	// Compute live character counts from the continuous stream of user initiated
	// changes in the text.
	textField.reactive.continuousTextValues.map { $0.characters.count }
	
	// Trigger `commit` whenever the button is pressed.
	button.reactive.pressed = CocoaAction(viewModel.commit)
	```
	
1. **Declarative Objective-C Dynamism**

	Create signals that are sourced by intercepting Objective-C objects,
	e.g. method call interception and object deinitialization.
	
	```swift
	// Notify after every time `viewWillAppear(_:)` is called.
	let appearing = object.reactive.trigger(for: #selector(viewWillAppear(_:)))
	
	// Observe the lifetime of `object`.
	object.reactive.lifetime.ended.observeCompleted(doCleanup)
	```

1. **Expressive, Safe Key Path Observation**

	Establish key-value observations in the form of `SignalProducer`s and
	`DynamicProperty`s, and enjoy the inherited composability.
	
	```swift
	// A producer that sends the current value of `keyPath`, followed by
	// subsequent changes.
	//
	// Terminate the KVO observation if the lifetime of `self` ends.
	let producer = object.reactive.values(forKeyPath: #keyPath(key))
		.take(during: self.reactive.lifetime)
	
	// A parameterized property that represents the supplied key path of the
	// wrapped object. It holds a weak reference to the wrapped object.
	let property = DynamicProperty<String>(object: person,
	                                       keyPath: #keyPath(person.name))
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
