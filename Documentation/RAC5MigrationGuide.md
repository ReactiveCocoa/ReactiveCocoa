# ReactiveCocoa 5.0 Migration Guide

* [Repository Split](#repository-split)
	* [ReactiveCocoa](#reactivecocoa)
	* [ReactiveSwift](#reactiveswift)
	* [ReactiveObjC](#reactiveobjc)
	* [ReactiveObjCBridge](#reactiveobjcbridge)
* [API Names](#api-names)
* [Signal](#signal)
	* [Lifetime Semantics](#lifetime-semantics)
* [SignalProducer](#signalproducer)
* [Properties](#properties)
* [Atomic](#atomic)

## Repository Split
In version 5.0, we split ReactiveCocoa into multiple repositories for reasons explained in the sections below. The following should help you get started with choosing the repositories you require:

**If you’re using only the Swift APIs**, you can continue to include ReactiveCocoa. You will also need to link against [ReactiveSwift][], which is now a dependency of ReactiveCocoa.

**If you’re using only the Objective-C APIs**, you can switch to using [ReactiveObjC][]. It has all the Obj-C code from RAC 2.

**If you’re using both the Swift and Objective-C APIs**, you likely require both ReactiveCocoa and [ReactiveObjCBridge][], which depend on [ReactiveSwift][] and [ReactiveObjC][].

### ReactiveCocoa
The ReactiveCocoa library is newly focused on Swift and the UI layers of Apple’s platforms, building on the work of [Rex](https://github.com/neilpa/Rex).

Reactive programming provides significant benefit in UI programming. RAC 3 and 4 focused on building out the new core Swift API. But we feel that those APIs have matured and it’s time for RAC-friendly extensions to AppKit and UIKit.

### ReactiveSwift
The core, platform-independent Swift APIs have been extracted to a new framework, [ReactiveSwift][].

As Swift continues to grow as a language and a platform, we hope that it will expand beyond Cocoa and Apple’s platforms. Separating the Swift code makes it possible to use the reactive paradigm on other platforms.

[ReactiveSwift]: https://github.com/ReactiveCocoa/ReactiveSwift

### ReactiveObjC
The 3.x and 4.x releases of ReactiveCocoa included the Objective-C code from ReactiveCocoa 2.x. That code has been moved to [ReactiveObjC][] because:

 1. It’s independent of the Swift code
 2. It has a separate user base
 3. It has a separate group of maintainers

We hope that this move will enable continued support of ReactiveObjC.

[ReactiveObjC]: https://github.com/ReactiveCocoa/ReactiveObjC

### ReactiveObjCBridge
Moving the Swift and Objective-C APIs to separate repositories meant that a new home was needed for the bridging layer between the two.

This bridge is an important tool for users that are working in mixed-language code bases. Whether you are slowly adding Swift to a mature product built with the ReactiveCocoa Objective-C APIs, or looking to adopt ReactiveCocoa in a mixed code base, the bridge is required to communicate between Swift and Objective-C code.

[ReactiveObjCBridge]: https://github.com/ReactiveCocoa/ReactiveObjCBridge

## API Names

We mostly adjusted the ReactiveCocoa API to follow the [Swift 3 API Design Guidelines](https://swift.org/blog/swift-3-api-design/), or to match the Cocoa and Foundation API changes that came with Swift 3 and the latest platform SDKs.

Lots has changed, but if you're already migrating to Swift 3 then that should not come as a surprise. Fortunately for you, we've provided annotations in the source that should help you while using the Swift 3 migration tool that ships with Xcode 8. When changes aren't picked up by the migrator, they are often provided for you as Fix-Its. 

**Tip:** You can apply all the suggested fix-its in the current scope by choosing Editor > Fix All In Scope from the main menu in Xcode, or by using the associated keyboard shortcut.

## Signal

### Lifetime Semantics

## SignalProducer

## Properties

## Atomic
