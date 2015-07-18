# Objective-C Bridging

While ReactiveCocoa 3.0 introduces an entirely new design, it also aims for maximum compatibility with RAC 2, to ease the pain of migration. To interoperate with RAC 2’s Objective-C APIs, RAC 3 offers bridging functions that can convert Objective-C types to Swift types and vice-versa. 

Because the APIs are based on fundamentally different designs, the conversion is not always one-to-one; however, every attempt has been made to faithfully translate the concepts between the two APIs (and languages).

The bridged types include:

 1. [`RACSignal` and `SignalProducer` or `Signal`](#racsignal-and-signalproducer-or-signal)
 1. [`RACCommand` and `Action`](#raccommand-and-action)
 1. [`RACScheduler` and `SchedulerType`](#racscheduler-and-schedulertype)
 1. [`RACDisposable` and `Disposable`](#racdisposable-and-disposable)

For the complete bridging API, including documentation, see [`ObjectiveCBridging.swift`][ObjectiveCBridging]. To learn more about how to migrate between ReactiveCocoa 2 and 3, see the [CHANGELOG][].

## `RACSignal` and `SignalProducer` or `Signal`

In RAC 3, “cold” signals are represented by the `SignalProducer` type, and “hot” signals are represented by the `Signal` type.

“Cold” `RACSignal`s can be converted into `SignalProducer`s using the new `toSignalProducer` method:

```swift
extension RACSignal {
	func toSignalProducer() -> SignalProducer<AnyObject?, NSError>
}
```

“Hot” `RACSignal`s cannot be directly converted into `Signal`s, because _any_ `RACSignal` subscription could potentially involve side effects. To obtain a `Signal`, use `RACSignal.toSignalProducer` followed by `SignalProducer.start`, which will make those potential side effects explicit.

For the other direction, use the `toRACSignal()` function.

When called with a `SignalProducer`, these functions will create a `RACSignal` to `start()` the producer once for each subscription:

```swift
func toRACSignal<T: AnyObject, E>(producer: SignalProducer<T, E>) -> RACSignal
func toRACSignal<T: AnyObject, E>(producer: SignalProducer<T?, E>) -> RACSignal
```

When called with a `Signal`, these functions will create a `RACSignal` that simply observes it:

```swift
func toRACSignal<T: AnyObject, E>(signal: Signal<T, E>) -> RACSignal
func toRACSignal<T: AnyObject, E>(signal: Signal<T?, E>) -> RACSignal
```

## `RACCommand` and `Action`

To convert `RACCommand`s into the new `Action` type, use the `toAction()` extension method:

```swift
extension RACCommand {
	func toAction() -> Action<AnyObject?, AnyObject?, NSError>
}
```

To convert `Action`s into `RACCommand`s, use the `toRACCommand()` function:

```swift
func toRACCommand<Output: AnyObject, E>(action: Action<AnyObject, Output, E>) -> RACCommand
func toRACCommand<Output: AnyObject, E>(action: Action<AnyObject?, Output, E>) -> RACCommand
```

**NOTE:** The `executing` properties of actions and commands are not synchronized across the API bridge. To ensure consistency, only observe the `executing` property from the base object (the one passed _into_ the bridge, not retrieved from it), so updates occur no matter which object is used for execution.

## `RACScheduler` and `SchedulerType`

Any `RACScheduler` instance is automatically a `DateSchedulerType` (and therefore a `SchedulerType`), and can be passed directly into any function or method that expects one.

Some (but not all) `SchedulerType`s from RAC 3 can be converted into `RACScheduler` instances, using the `toRACScheduler()` method:

```swift
extension ImmediateScheduler {
	func toRACScheduler() -> RACScheduler
}

extension UIScheduler {
	func toRACScheduler() -> RACScheduler
}

extension QueueScheduler {
	func toRACScheduler() -> RACScheduler
}
```

## `RACDisposable` and `Disposable`

Any `RACDisposable` instance is automatically a `Disposable`, and can be used directly anywhere a type conforming to `Disposable` is expected.

Although there is no direct conversion from `Disposable` into `RACDisposable`, it is easy to do manually:

```swift
let swiftDisposable: Disposable
let objcDisposable = RACDisposable {
    swiftDisposable.dispose()
}
```

[CHANGELOG]: ../CHANGELOG.md
[ObjectiveCBridging]: ../ReactiveCocoa/Swift/ObjectiveCBridging.swift
