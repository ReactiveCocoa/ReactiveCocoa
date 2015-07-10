# Objective-C Bridging

While ReactiveCocoa 3.0 introduces an entirely new design, it also aims for maximum compatibility with RAC 2 to ease the pain of migratin. To support interoperability with RAC 2's Objective-C APIs, RAC 3 offers bridging functions that can convert RAC 2 types to RAC 3 and vice versa. 

Because the APIs are based on fundamentally different designs, the conversion is not always one-to-one; however, every attempt has been made to faithfully translate the concepts between the two APIs (and languages).

Below is the list of common conversions currently available.

### Converting `RACSignal` to `SignalProducer` (or `Signal`)

In RAC 3, "cold" signals are represented by the `SignalProducer` type, and "hot" signals are represented by the `Signal` type. ([Learn more about RAC 3's architectural changes](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/swift-development/CHANGELOG.md)).

"Cold" `RACSignal`s from RAC 2 can be converted to the new `SignalProducer` type using the new `toSignalProducer` method on `RACSignal`. 

```
extension RACSignal {
	func toSignalProducer(file: String = __FILE__, line: Int = __LINE__) -> SignalProducer<AnyObject?, NSError>
}
```

"Hot" `RACSignal`s cannot be converted to `Signal`s because any `RACSignal` subscription could potentially involve side-effects. To obtain a `Signal`, use `RACSignal.toSignalProducer` followed by `SignalProducer.start`, thereby making those side effects explicit.

Use the `toRACSignal()` function to convert from `SignalProducer<AnyObject?, ErrorType>` or `Signal<AnyObject?, ErrorType>` to `RACSignal *`.

```
func toRACSignal<T: AnyObject, E>(producer: SignalProducer<T, E>) -> RACSignal
func toRACSignal<T: AnyObject, E>(producer: SignalProducer<T?, E>) -> RACSignal
```

The `RACSignal` created by these functions will `start()` the producer once for each subscription.

```
func toRACSignal<T: AnyObject, E>(signal: Signal<T, E>) -> RACSignal
func toRACSignal<T: AnyObject, E>(signal: Signal<T?, E>) -> RACSignal
```

The `RACSignal` created by these functions will observe the given signal. 

### Converting `RACCommand` to `Action`

Use `RACCommand.toAction` to convert `RACCommand *` to `Action<AnyObject?, AnyObject?, NSError>`.

```
extension RACCommand {
	func toAction(file: String = __FILE__, line: Int = __LINE__) -> Action<AnyObject?, AnyObject?, NSError>
}
```

Use the `toRACCommand` function to convert `Action<AnyObject?, AnyObject?, ErrorType>` to `RACCommand *`.

```
func toRACCommand<Output: AnyObject, E>(action: Action<AnyObject, Output, E>) -> RACCommand
func toRACCommand<Output: AnyObject, E>(action: Action<AnyObject?, Output, E>) -> RACCommand
```

Unfortunately, the `executing` properties of actions and commands are not synchronized across the API bridge. To ensure consistency, only observe the `executing` property from the base object (the one passed _into_ the bridge, not retrieved from it), so updates occur no matter which object is used for execution.

### Converting `SchedulerType`s to `RACScheduler

TODO`
