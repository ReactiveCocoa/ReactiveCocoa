# 5.0

### Table of Contents
1. [Repository Split](#repository-split)
1. [Swift 3.0 API Renaming](#swift-30-api-renaming)
1. [New in 5.0: Cocoa Extensions](#new-in-50-cocoa-extensions)
1. [Changes in ReactiveSwift 1.0](#changes-in-reactiveswift-10)
1. [Migrating from the ReactiveObjC API](#migrating-from-the-reactiveobjc-api)

### Repository Split
In version 5.0, we split ReactiveCocoa into multiple repositories for reasons explained in the sections below. The following should help you get started with choosing the repositories you require:

**If you’re using only the Swift APIs**, you can continue to include ReactiveCocoa. You will also need to link against [ReactiveSwift][], which is now a dependency of ReactiveCocoa.

**If you’re using only the Objective-C APIs**, you can switch to using [ReactiveObjC][]. It has all the Obj-C code from RAC 2.

**If you’re using both the Swift and Objective-C APIs**, you likely require both ReactiveCocoa and [ReactiveObjCBridge][], which depend on [ReactiveSwift][] and [ReactiveObjC][].

**Attention:** If youre using ReactiveCocoa, you'll most likely need to import ReactiveSwift as well when using classes or operators that are implemented in ReactiveSwift.

#### ReactiveCocoa
The ReactiveCocoa library is newly focused on Swift and the UI layers of Apple’s platforms, building on the work of [Rex](https://github.com/neilpa/Rex).

Reactive programming provides significant benefit in UI programming. RAC 3 and 4 focused on building out the new core Swift API. But we feel that those APIs have matured and it’s time for RAC-friendly extensions to AppKit and UIKit.

#### ReactiveSwift
The core, platform-independent Swift APIs have been extracted to a new framework, [ReactiveSwift][].

As Swift continues to grow as a language and a platform, we hope that it will expand beyond Cocoa and Apple’s platforms. Separating the Swift code makes it possible to use the reactive paradigm on other platforms.

[ReactiveSwift]: https://github.com/ReactiveCocoa/ReactiveSwift

#### ReactiveObjC
The 3.x and 4.x releases of ReactiveCocoa included the Objective-C code from ReactiveCocoa 2.x. That code has been moved to [ReactiveObjC][] because:

 1. It’s independent of the Swift code
 2. It has a separate user base
 3. It has a separate group of maintainers

We hope that this move will enable continued support of ReactiveObjC.

[ReactiveObjC]: https://github.com/ReactiveCocoa/ReactiveObjC

##### ReactiveObjCBridge
Moving the Swift and Objective-C APIs to separate repositories meant that a new home was needed for the bridging layer between the two.

This bridge is an important tool for users that are working in mixed-language code bases. Whether you are slowly adding Swift to a mature product built with the ReactiveCocoa Objective-C APIs, or looking to adopt ReactiveCocoa in a mixed code base, the bridge is required to communicate between Swift and Objective-C code.

[ReactiveObjCBridge]: https://github.com/ReactiveCocoa/ReactiveObjCBridge

### Swift 3.0 API Renaming

We mostly adjusted the ReactiveCocoa API to follow the [Swift 3 API Design Guidelines](https://swift.org/blog/swift-3-api-design/), or to match the Cocoa and Foundation API changes that came with Swift 3 and the latest platform SDKs.

Lots has changed, but if you're already migrating to Swift 3 then that should not come as a surprise. Fortunately for you, we've provided annotations in the source that should help you while using the Swift 3 migration tool that ships with Xcode 8. When changes aren't picked up by the migrator, they are often provided for you as Fix-Its.

**Tip:** You can apply all the suggested fix-its in the current scope by choosing Editor > Fix All In Scope from the main menu in Xcode, or by using the associated keyboard shortcut.

### New in 5.0: Cocoa Extensions

#### Foundation: Object Interception

RAC 5.0 includes a few object interception tools from ReactiveObjC, remastered for ReactiveSwift.
	
1. **Method Call Interception**

	Create signals that are sourced by intercepting Objective-C objects.
	
	```swift
	// Notify after every time `viewWillAppear(_:)` is called.
	let appearing = view.reactive.trigger(for: #selector(viewWillAppear(_:)))
	```
	
1. **Object Lifetime**

	Obtain a `Lifetime` token for any `NSObject` to observe their deinitialization.

	```swift
	// Observe the lifetime of `object`.
	object.reactive.lifetime.ended.observeCompleted(doCleanup)
	```

1. **Expressive, Safe Key Path Observation**

	Establish key-value observations in the form of [`SignalProducer`][]s and
	strong-typed `DynamicProperty`s, and enjoy the inherited composability.
	
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

These are accessible via the `reactive` magic property that is available on any ObjC objects.

#### AppKit & UIKit: UI bindings

UI components now expose a collection of binding targets to which can be bound from any arbitrary streams of values.

1. **UI Bindings**

	UI components exposes [`BindingTarget`][]s, which accept bindings from any
	kind of streams of values via the `<~` operator.

	```swift
	// Bind the `name` property of `person` to the text value of an `UILabel`.
	nameLabel.reactive.text <~ person.name
	```

1. **Controls and User Interactions**

	Interactive UI components expose [`Signal`][]s for control events
	and updates in the control value upon user interactions.
	
	A selected set of controls provide a convenience, expressive binding
	API for [`Action`][]s.
	
	
	```swift
	// Update `allowsCookies` whenever the toggle is flipped.
	preferences.allowsCookies <~ toggle.reactive.isOnValues 
	
	// Compute live character counts from the continuous stream of user initiated
	// changes in the text.
	textField.reactive.continuousTextValues.map { $0.characters.count }
	
	// Trigger `commit` whenever the button is pressed.
	button.reactive.pressed = CocoaAction(viewModel.commit)
	```

These are accessible via the `reactive` magic property that is available on any ObjC objects.

### Changes in ReactiveSwift 1.0

#### Signal: Lifetime Semantics

Prior to RAC 5.0, `Signal`s lived and continued to emit values (and side effects) until they completed. This was very confusing, even for RAC veterans. So [changes have been made](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/2959) to the lifetime semantics. `Signal`s now live and continue to emit events only while either (a) they have observers or (b) they are retained. This clears up a number of unexpected cases and makes `Signal`s much less dangerous.

#### SignalProducer: `buffer` has been removed.
Consider using `Signal.pipe` for `buffer(0)`, `MutableProperty` for `buffer(1)` or `replayLazily(upTo: n)` for `buffer(n)`.

#### Properties: Composition
Properties are now composable! They have many of the same operators as `Signal` and `SignalProducer`: `map`, `filter`, `combineLatest`, `zip`, `flatten`, etc.

#### Properties: Lifetime Semantics
Composed properties, including those created via `Property(initial:then:)`, are semantically a view to their ultimate sources. In other words, the lifetime, the signal and the producer would respect the ultimate sources, and deinitialization of an instance of composed property would not have an effect on these.

```swift
let property = MutableProperty(1)
var composed: Property<Int> = property.map { $0 + 10 }
composed.startWithValues { print("\($0)") }
composed = nil

property.value = 2
// The produced signal is still alive, printing `12` to the output stream.
```

#### Atomic: A more efficient `modify`

`Atomic.modify` now passes its value to the supplied action as an `inout`. This enables the compiler to optimize it as an in-place mutation, which benefits collections, large `struct`s and `struct`s with considerable amount of references.

Moreover, `Atomic.modify` now returns the returned value from the supplied action, instead of the old value as in RAC 4.x, so as to reduce unnecessary copying.

```swift
// ReactiveCocoa 4.0
let old = atomicCount.modify { $0 + 1 }

// ReactiveSwift 1.0
let old = atomicCount.modify { value in
    let old = value
    value += 1
    return old
}
```

#### BindingTarget

The new `BindingTargetProtocol` protocol has been formally introduced to represent an entity to which can form a unidirectional binding using the `<~` operator. A new type `BindingTarget` has also been introduced to represent non-observable targets that are expected to only be written to.

```swift
// The `UIControl` exposes a `isEnabled` binding target. 
control.isEnabled <~ viewModel.isEnabled
```

#### Lifetime

`Lifetime` is introduced to represent the lifetime of any arbitrary reference types. It works by completing the signal when its wrapping `Lifetime.Token` deinitializes with the associated reference type. While it is provided as `NSObject.reactive.lifetime` on Objective-C objects, it can also be associated manually with Swift classes to provide the same semantics.

```swift
public final class MyController {
	private let token = Lifetime.Token()
	public let lifetime: Lifetime
	
	public init() {
		lifetime = Lifetime(token)
	}
}
```

### Migrating from the ReactiveObjC API

#### Primitives
<table>
	<thead>
	<tr>
		<th>ReactiveObjC</th>
		<th>ReactiveCocoa 5.0</th>
	</tr>
	</thead>
	<tbody>
	<tr>
		<td>Cold <code>RACSignal</code></td>
		<td><code>SignalProducer</code></td>
	</tr>
	<tr>
		<td>Hot <code>RACSignal</code></td>
		<td><code>Signal</code></td>
	</tr>
	<tr>
		<td>Serial <code>RACCommand</code></td>
		<td><code>Action</code></td>
	</tr>
	<tr>
		<td>Concurrent <code>RACCommand</code></td>
		<td>Currently no counterpart.</td>
	</tr>
	</tbody>
</table>

#### Macros
<table>
	<thead>
	<tr>
		<th>ReactiveObjC</th>
		<th>ReactiveCocoa 5.0</th>
	</tr>
	</thead>
	<tbody>
	<tr>
		<td><code>RAC(label, text)</code></td>
		<td>Discover binding targets via <code>.reactive</code> on UI components.
			<p><pre lang="swift">label.reactive.text <~ viewModel.name</pre></p>
		</td>
	</tr>
	<tr>
		<td><code>RACObserve(object, keyPath)</code></td>
		<td><code>NSObject.reactive.values(forKeyPath:)</code></td>
	</tr>
	</tbody>
</table>
#### NSObject interception
<table>
	<thead>
	<tr>
		<th>ReactiveObjC</th>
		<th>ReactiveCocoa 5.0</th>
	</tr>
	</thead>
	<tbody>
	<tr>
		<td><code>rac_willDeallocSignal</code></td>
		<td><code>NSObject.reactive.lifetime</code>, in conjunction with the <code>take(during:)</code> operator.
			<p><pre lang="swift">signal.take(during: object.reactive.lifetime)</pre></p>
		</td>
	</tr>
	<tr>
		<td><code>rac_liftSelector:withSignals:</code></td>
		<td>Apply <code>combineLatest</code> to your signals, and invoke the method in <code>observeValues</code>.
			<p>
<pre lang="swift">Signal.combineLatest(signal1, signal2)
	.take(during: self.reactive.lifetime)
	.observeValues { [weak self] in self?.perform(first: $0, second: $1) }</pre>
			</p>
		</td>
	</tr>
	<tr>
		<td><code>rac_signalForSelector:</code></td>
		<td><code>NSObject.reactive.trigger(for:)</code> and <code>NSObject.reactive.signal(for:)</code></td>
	</tr>
	<tr>
		<td><code>rac_signalForSelector:fromProtocol:</code></td>
		<td>Currently no counterpart.</td>
	</tr>
	</tbody>
</table>
#### Control bindings and observations
<table>
	<thead>
	<tr>
		<th>ReactiveObjC</th>
		<th>ReactiveCocoa 5.0</th>
	</tr>
	</thead>
	<tbody>
	<tr>
		<td>Control value changes, e.g. <code>textField.rac_textSignal()</code></td>
		<td>Discover control value `Signal`s via <code>.reactive</code> on UI components.
			<p><pre lang="swift">viewModel.searchString <~ textField.reactive.textValues</pre></p>
		</td>
	</tr>
	<tr>
		<td><code>rac_signalForControlEvents:</code></td>
		<td><code>UIControl.reactive.trigger(for:)</code></td>
	</tr>
	<tr>
		<td><code>rac_command</td>
		<td>Discover action binding APIs via <code>.reactive</code> on UI components.
			<p><pre lang="swift">button.reactive.pressed = CocoaAction(viewModel.submitAction)</pre></p>
		</td>
	</tr>
	</tbody>
</table>
# 4.0

If you’re new to the Swift API and migrating from RAC 2, start with the [3.0 changes](#30). This section only covers the differences between `3.0` and `4.0`.

Just like in `RAC 3`, because Objective-C is still in widespread use, 99% of `RAC 2.x` code will continue to work under `RAC 4.0` without any changes. That is, `RAC 2.x` primitives are still available in `RAC 4.0`.

`ReactiveCocoa 4.0` targets **Xcode 7.2.x** and **Swift 2.1.x**, and it supports `iOS 8.0`, `watchOS 2.0`, `tvOS 9.0` and `OS X 10.9`.


#### Signal operators are protocol extensions

The biggest change from `RAC 3` to `RAC 4` is that `Signal` and `SignalProducer` operators are implemented as **protocol extensions** instead of global functions. This is similar to many of the collection protocol changes in the `Swift 2` standard
library.

This enables chaining signal operators with normal dot-method calling syntax, which makes autocompleting operators a lot easier.
Previously the custom `|>` was required to enable chaining global functions without a mess of nested calls and parenthesis.

```swift
/// RAC 3
signal
  |> filter { $0 % 2 == 0 }
  |> map { $0 * $0 }
  |> observe { print($0) }

/// RAC 4
signal
  .filter { $0 % 2 == 0 }
  .map { $0 * $0 }
  .observeNext { print($0) }
```

Additionally, this means that `SignalProducer` operators are less “magic”. In RAC 3 the `Signal` operators were implicitly lifted to work on `SignalProducer` via `|>`. This was a point of confusion for some, especially when browsing the
source looking for these operators. Now as protocol extensions, the `SignalProducer` operators are explicitly implemented in terms of their `Signal` counterpart when available.

#### Removal of `|>` custom operator

As already alluded to above, the custom `|>` operator for chaining signals has been removed. Instead standard method calling syntax is used for chaining operators.

#### Event cases are no longer boxed

The improvements to associated enum values in `Swift 2` mean that `Event` case no longer need to be `Box`ed. In fact, the `Box` dependency has been removed completely from `RAC 4`.

#### Replacements for the `start` and `observer` overloads

The `observe` and `start` overloads taking `next`, `error`, etc. optional function parameters have been removed. They’ve been replaced with methods taking a single function with
the target `Event` case — `observeNext`, `startWithNext`, and the same for `failed` and `completed`. See [#2311](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2311) and [#2318](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2318) for more details.

#### Renamed `try` and `catch` operators

The `try` and `catch` operators were renamed because of the addition of the error handling keywords with the same name. They are now `attempt` and `flatMapError` respectively. Also, `tryMap` was renamed to `attemptMap` for consistency.

#### `flatten` and `flatMap` are now possible for all 4 combinations of `Signal`+`SignalProducer`

This fills a gap that was missing in `RAC 3`. It’s a common pattern to have signals-of-signals or signals-of-producers.
The addition of `flatten` and `flatMap` over these makes it now possible to work with any combination of `Signal`s and `SignalProducer`s.

#### Renamed `Event.Error` to `Event.Failed`

The `Error` case of `Event` has changed to `Failed`. This aims to help clarify the terminating nature of failure/error events and puts them in the same tense as other terminating cases (`Interrupted` and `Completed`). Likewise, some operations and parameters have been renamed (e.g. `Signal.observeError` is now `Signal.observeFailed`, `Observer.sendError` is now `Observer.sendFailed`).

#### Renamed signal generic parameters

The generic parameters of `Signal`, `SignalProducer`, and other related types
have been renamed to `Value` and `Error` from `T` and `E` respectively. This
is in-line with changes to the standard library to give more descriptive names
to type parameters for increased clarity. This should have limited impact,
only affecting generic, custom signal/producer extensions.

#### Added missing `SignalProducer` operators

There were some `Signal` operators that were missing `SignalProducer` equivalents:

* `takeUntil`
* `combineLatestWith`
* `sampleOn`
* `takeUntilReplacement`
* `zipWith`

#### Added new operators:

* `Signal.on`.
* `Signal.merge(signals:)`.
* `Signal.empty`.
* `skipUntil`.
* `replayLazily` ([#2639](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2639)).


#### Renamed `PropertyOf<T>` to `AnyProperty<T>`

This is in-line with changes to the standard library in `Swift 2`.

#### Enhancements to `PropertyType`

`MutableProperty` received 3 new methods, similar to those in `Atomic`: `modify`, `swap`, and `withValue`.
Additionally, all `PropertyType`s now have a `signal: Signal<T>` in addition to their existing `producer: SignalProducer<T>` property.

#### Publicized `Bag` and `Atomic`

`Bag` and `Atomic` are now public. These are useful when creating custom operators for RAC types.

#### `SignalProducer.buffer` no longer has a default capacity

In order to force users to think about the desired capacity, this no longer defaults to `Int.max`. Prior to this change one could have inadvertently cached every value emitted by the `SignalProducer`. This needs to be specified manually now.

#### Added `SignalProducer.replayLazily` for multicasting

It’s still recommended to use `SignalProducer.buffer` or `PropertyType` when buffering behavior is desired. However, when you need to compose an existing `SignalProducer` to avoid duplicate side effects, this operator is now available.

The full semantics of the operator are documented in the code, and you can see [#2639](https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2639) for full details.


# 3.0

ReactiveCocoa 3.0 includes the first official Swift API, which is intended to
eventually supplant the Objective-C API entirely.

However, because migration is hard and time-consuming, and because Objective-C
is still in widespread use, 99% of RAC 2.x code will continue to work under RAC
3.0 without any changes.

Since the 3.0 changes are entirely additive, this document will discuss how
concepts from the Objective-C API map to the Swift API. For a complete diff of
all changes, see [the 3.0 pull
request](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/1382).

**[Additions](#additions)**

 1. [Parameterized types](#parameterized-types)
 1. [Interrupted event](#interrupted-event)
 1. [Objective-C bridging](#objective-c-bridging)

**[Replacements](#replacements)**

 1. [Hot signals are now Signals](#hot-signals-are-now-signals)
 1. [Cold signals are now SignalProducers](#cold-signals-are-now-signalproducers)
 1. [Commands are now Actions](#commands-are-now-actions)
 1. [Flattening/merging, concatenating, and switching are now one operator](#flatteningmerging-concatenating-and-switching-are-now-one-operator)
 1. [Using PropertyType instead of RACObserve and RAC](#using-propertytype-instead-of-racobserve-and-rac)
 1. [Using Signal.pipe instead of RACSubject](#using-signalpipe-instead-of-racsubject)
 1. [Using SignalProducer.buffer instead of replaying](#using-signalproducerbuffer-instead-of-replaying)
 1. [Using startWithSignal instead of multicasting](#using-startwithsignal-instead-of-multicasting)

**[Minor changes](#minor-changes)**

 1. [Disposable changes](#disposable-changes)
 1. [Scheduler changes](#scheduler-changes)

## Additions

### Parameterized types

Thanks to Swift, **it is now possible to express the type of value that a signal
can send. RAC also requires that the type of errors be specified.**

For example, `Signal<Int, NSError>` is a signal that may send zero or more
integers, and which may send an error of type `NSError`.

**If it is impossible for a signal to error out, use the built-in
[`NoError`](ReactiveCocoa/Swift/Errors.swift) type**
(which can be referred to, but never created) to represent that
case—for example, `Signal<String, NoError>` is a signal that may send zero or
more strings, and which will _not_ send an error under any circumstances.

Together, these additions make it much simpler to reason about signal
interactions, and protect against several kinds of common bugs that occurred in
Objective-C.

### Interrupted event

In addition to the `Next`, `Error`, and `Completed` events that have always been
part of RAC, version 3.0 [adds another terminating
event](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/1735)—called
`Interrupted`—that is used to communicate cancellation.

Now, **whenever a [producer](#cold-signals-are-now-signalproducers) is disposed
of, one final `Interrupted` event will be sent to all consumers,** giving them
a chance to react to the cancellation.

Similarly, observing a [hot signal](#hot-signals-are-now-signals) that has
already terminated will immediately result in an `Interrupted` event, to clearly
indicate that no further events are possible.

This brings disposal semantics more in line with normal event delivery, where
events propagate downstream from producers to consumers. The result is a simpler
model for reasoning about non-erroneous, yet unsuccessful, signal terminations.

**Note:** Custom `Signal` and `SignalProducer` operators should handle any received
`Interrupted` event by forwarding it to their own observers. This ensures that
interruption correctly propagates through the whole signal chain.

### Objective-C bridging

**To support interoperation between the Objective-C APIs introduced in RAC 2 and
the Swift APIs introduced in RAC 3, the framework offers [bridging
functions](ReactiveCocoa/Swift/ObjectiveCBridging.swift)** that can convert types
back and forth between the two.

Because the APIs are based on fundamentally different designs, the conversion is
not always one-to-one; however, every attempt has been made to faithfully
translate the concepts between the two APIs (and languages).

**Common conversions include:**

* The `RACSignal.toSignalProducer` method **†**
    * Converts `RACSignal *` to `SignalProducer<AnyObject?, NSError>`
* The `toRACSignal()` function
    * Converts `SignalProducer<AnyObject?, ErrorType>` to `RACSignal *`
    * Converts `Signal<AnyObject?, ErrorType>` to `RACSignal *`
* The `RACCommand.toAction` method **‡**
    * Converts `RACCommand *` to `Action<AnyObject?, AnyObject?, NSError>`
* The `toRACCommand` function **‡**
    * Converts `Action<AnyObject?, AnyObject?, ErrorType>` to `RACCommand *`

**†** It is not possible (in the general case) to convert arbitrary `RACSignal`
instances to `Signal`s, because any `RACSignal` subscription could potentially
involve side effects. To obtain a `Signal`, use `RACSignal.toSignalProducer`
followed by `SignalProducer.start`, thereby making those side effects explicit.

**‡** Unfortunately, the `executing` properties of actions and commands are not
synchronized across the API bridge. To ensure consistency, only observe the
`executing` property from the base object (the one passed _into_ the bridge, not
retrieved from it), so updates occur no matter which object is used for
execution.

## Replacements

### Hot signals are now Signals

In the terminology of RAC 2, a “hot” `RACSignal` does not trigger any side effects
when a `-subscribe…` method is called upon it. In other words, hot signals are
entirely producer-driven and push-based, and consumers (subscribers) cannot have
any effect on their lifetime.

This pattern is useful for notifying observers about events that will occur _no
matter what_. For example, a `loading` boolean might flip between true and false
regardless of whether anything is observing it.

Concretely, _every_ `RACSubject` is a kind of hot signal, because the events
being forwarded are not determined by the number of subscribers on the subject.

In RAC 3, **“hot” signals are now solely represented by the
[`Signal`](ReactiveCocoa/Swift/Signal.swift) class**, and “cold” signals have been
[separated into their own type](#cold-signals-are-now-signalproducers). This
reduces complexity by making it clear that no `Signal` object can trigger side
effects when observed.

### Cold signals are now SignalProducers

In the terminology of RAC 2, a “cold” `RACSignal` performs its work one time for
_every_ subscription. In other words, cold signals perform side effects when
a `-subscribe…` method is called upon them, and may be able to cancel
in-progress work if `-dispose` is called upon the returned `RACDisposable`.

This pattern is broadly useful because it minimizes unnecessary work, and
allows operators like `take`, `retry`, `concat`, etc. to manipulate when work is
started and cancelled. Cold signals are also similar to how [futures and
promises](http://en.wikipedia.org/wiki/Futures_and_promises) work, and can be
useful for structuring asynchronous code (like network requests).

In RAC 3, **“cold” signals are now solely represented by the
[`SignalProducer`](ReactiveCocoa/Swift/SignalProducer.swift) class**, which
clearly indicates their relationship to [“hot”
signals](#hot-signals-are-now-signals). As the name indicates, a signal
_producer_ is responsible for creating
a [_signal_](#hot-signals-are-now-signals) (when started), and can
perform work as part of that process—meanwhile, the signal can have any number
of observers without any additional side effects.

### Commands are now Actions

Instead of the ambiguously named `RACCommand`, the Swift API offers the
[`Action`](ReactiveCocoa/Swift/Action.swift) type—named as such because it’s
mainly useful in UI programming—to fulfill the same purpose.

Like the rest of the Swift API, actions are
[parameterized](#parameterized-types) by the types they use. **An action must
indicate the type of input it accepts, the type of output it produces, and
what kinds of errors can occur (if any).** This eliminates a few classes of type
error, and clarifies intention.

Actions are also intended to be simpler overall than their predecessor:

 * **Unlike commands, actions are not bound to or dependent upon the main
   thread**, making it easier to reason about when they can be executed and when
   they will generate notifications.
 * **Actions also only support serial execution**, because concurrent execution
   was a rarely used feature of `RACCommand` that added significant complexity
   to the interface and implementation.

Because actions are frequently used in conjunction with AppKit or UIKit, there
is also a `CocoaAction` class that erases the type parameters of an `Action`,
allowing it to be used from Objective-C.

As an example, an action can be wrapped and bound to `UIControl` like so:

```swift
self.cocoaAction = CocoaAction(underlyingAction)
self.button.addTarget(self.cocoaAction, action: CocoaAction.selector, forControlEvents: UIControlEvents.TouchUpInside)
```

### Flattening/merging, concatenating, and switching are now one operator

RAC 2 offers several operators for transforming a signal-of-signals into one
`RACSignal`, including:

 * `-flatten`
 * `-flattenMap:`
 * `+merge:`
 * `-concat`
 * `+concat:`
 * `-switchToLatest`

Because `-flattenMap:` is the easiest to use, it was often
incorrectly chosen even when concatenation or switching semantics are more
appropriate.

**RAC 3 distills these concepts down into just two operators, `flatten` and `flatMap`.**
Note that these do _not_ have the same behavior as `-flatten` and `-flattenMap:`
from RAC 2. Instead, both accept a “strategy” which determines how the
producer-of-producers should be integrated, which can be one of:

 * `.Merge`, which is equivalent to RAC 2’s `-flatten` or `+merge:`
 * `.Concat`, which is equivalent to `-concat` or `+concat:`
 * `.Latest`, which is equivalent to `-switchToLatest`

This reduces the API surface area, and forces callers to consciously think about
which strategy is most appropriate for a given use.

**For streams of exactly one value, calls to `-flattenMap:` can be replaced with
`flatMap(.Concat)`**, which has the additional benefit of predictable behavior if
the input stream is refactored to have more values in the future.

### Using PropertyType instead of RACObserve and RAC

To be more Swift-like, RAC 3 de-emphasizes [Key-Value Coding](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/KeyValueCoding.html) (KVC)
and [Key-Value Observing](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) (KVO)
in favor of a less “magical” representation for properties.
**The [`PropertyType` protocol and implementations](ReactiveCocoa/Swift/Property.swift)
replace most uses of the `RACObserve()` and `RAC()` macros.**

For example, `MutableProperty` can be used to represent a property that can be
bound to. If changes to that property should be visible to consumers, it can
additionally be wrapped in `PropertyOf` (to hide the mutable bits) and exposed
publicly.

**If KVC or KVO is required by a specific API**—for example, to observe changes
to `NSOperation.executing`—RAC 3 offers a `DynamicProperty` type that can wrap
those key paths. Use this class with caution, though, as it can’t offer any type
safety, and many APIs (especially in AppKit and UIKit) are not documented to be
KVO-compliant.

### Using Signal.pipe instead of RACSubject

Since the `Signal` type, like `RACSubject`, is [always “hot”](#hot-signals-are-now-signals),
there is a special class method for creating a controllable signal. **The
`Signal.pipe` method can replace the use of subjects**, and expresses intent
better by separating the observing API from the sending API.

To use a pipe, set up observers on the signal as desired, then send values to
the sink:

```swift
let (signal, sink) = Signal<Int, NoError>.pipe()

signal.observe(next: { value in
    print(value)
})

// Prints each number
sendNext(sink, 0)
sendNext(sink, 1)
sendNext(sink, 2)
```

### Using SignalProducer.buffer instead of replaying

The producer version of
[`Signal.pipe`](#using-signalpipe-instead-of-racsubject),
**the `SignalProducer.buffer` method can replace replaying** with
`RACReplaySubject` or any of the `-replay…` methods.

Conceptually, `buffer` creates a (optionally bounded) queue for events, much
like `RACReplaySubject`, and replays those events when new `Signal`s are created
from the producer.

For example, to replay the values of an existing `Signal`, it just needs to be
fed into the write end of the buffer:

```swift
let signal: Signal<Int, NoError>
let (producer, sink) = SignalProducer<Int, NoError>.buffer()

// Saves observed values in the buffer
signal.observe(sink)

// Prints each value buffered
producer.start(next: { value in
    print(value)
})
```

### Using startWithSignal instead of multicasting

`RACMulticastConnection` and the `-publish` and `-multicast:` operators were
always poorly understood features of RAC 2. In RAC 3, thanks to the `Signal` and
`SignalProducer` split, **the `SignalProducer.startWithSignal` method can
replace multicasting**.

`startWithSignal` allows any number of observers to attach to the created signal
_before_ any work is begun—therefore, the work (and any side effects) still
occurs just once, but the values can be distributed to multiple interested
observers. This fulfills the same purpose of multicasting, in a much clearer and
more tightly-scoped way.

For example:

```swift
let producer = timer(5, onScheduler: QueueScheduler.mainQueueScheduler).take(3)

// Starts just one timer, sending the dates to two different observers as they
// are generated.
producer.startWithSignal { signal, disposable in
    signal.observe(next: { date in
        print(date)
    })

    signal.observe(someOtherObserver)
}
```

## Minor changes

### Disposable changes

[Disposables](ReactiveCocoa/Swift/Disposable.swift) haven’t changed much overall
in RAC 3, besides the addition of a protocol and minor naming tweaks.

The biggest change to be aware of is that **setting
`SerialDisposable.innerDisposable` will always dispose of the previous value**,
which helps prevent resource leaks or logic errors from forgetting to dispose
manually.

### Scheduler changes

RAC 3 replaces the multipurpose `RACScheduler` class with two protocols,
[`SchedulerType` and `DateSchedulerType`](ReactiveCocoa/Swift/Scheduler.swift), with multiple implementations of each.
This design indicates and enforces the capabilities of each scheduler using the type
system.

In addition, **the `mainThreadScheduler` has been replaced with `UIScheduler` and
`QueueScheduler.mainQueueScheduler`**. The `UIScheduler` type runs operations as
soon as possible on the main thread—even synchronously (if possible), thereby
replacing RAC 2’s `-performOnMainThread` operator—while
`QueueScheduler.mainQueueScheduler` will always enqueue work after the current
run loop iteration, and can be used to schedule work at a future date.

[`Signal`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#signals
[`SignalProducer`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#signal-producers
[`Action`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#actions
[`BindingTarget`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#binding-target
