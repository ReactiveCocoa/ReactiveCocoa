# RAC 5.0 Migration Guide

## Repository Split
As part of RAC 5.0, ReactiveCocoa has been split into multiple repositories. _The rationale for this change is explained below._

**If you’re using only the Swift APIs**, you can continue to include ReactiveCocoa. You will also need to link against [ReactiveSwift][], which is now a dependency of ReactiveCocoa.

**If you’re using only the Objective-C APIs**, you can switch to using [ReactiveObjC][]. It has all the Obj-C code from RAC 2.

**If you’re using both the Swift and Objective-C APIs**, you will most likely want to use both ReactiveCocoa and [ReactiveObjCBridge][], which depend on [ReactiveSwift][] and [ReactiveObjC][].

### ReactiveCocoa
The ReactiveCocoa library is newly focused on Swift and the UI layers of Apple’s platforms, building on the work of [Rex](https://github.com/neilpa/Rex).

Reactive programming provides significant benefit in UI programming. RAC 3 and 4 focused on building out the new core Swift API. But we feel that those APIs have matured and it’s time for RAC-friendly extensions to AppKit and UIKit.

### ReactiveSwift
The core, platform-independent Swift APIs have been extracted to a new framework, [ReactiveSwift][].

As Swift continues to grow as a language and a platform, we hope that it will expand beyond Cocoa and Apple’s platforms. Separating the Swift code makes it possible to use the reactive paradigm on other platforms.

[ReactiveSwift]: https://github.com/ReactiveCocoa/ReactiveSwift

### ReactiveObjC
RAC 3/4 included the Objective-C code from RAC 2. That code has been moved to [ReactiveObjC][] because:

 1. It’s independent of the Swift code
 2. It has a separate user base
 3. It has a separate group of maintainers

We hope that this move will enable continued support of ReactiveObjC.

[ReactiveObjC]: https://github.com/ReactiveCocoa/ReactiveObjC

### ReactiveObjCBridge
Moving the Swift and Objective-C APIs to separate repositories meant that a new home was need for the bridging layer between the two.

This value will remain an important tool for anyone who’s heavily invested in the Objective-C RAC APIs as they (hopefully) move gradually to Swift.

[ReactiveObjCBridge]: https://github.com/ReactiveCocoa/ReactiveObjCBridge
