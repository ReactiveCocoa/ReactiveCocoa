# Rex [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
Extensions for [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) that may not fit in the core framework.

New development targets RAC 4/Swift 2/Xcode 7. For RAC 3 support [see the 0.5 release](https://github.com/neilpa/Rex/releases/tag/v0.5.0).

## Signal
All `Signal` operators are available for `SignaProducer`s too via explicit `lift`ing.

##### `filterMap`
Applies `transform` to values from `signal` with non-nil results unwrapped and forwared on the returned signal. This is equivalent to `map { … } .filter { $0 != nil } .map { $0! }`  but without creating extra intermediate signals.

```swift
func filterMap<U>(transform: T -> U?) -> Signal<U, E>
```

##### `ignoreError`
Wraps a `signal` in a version that drops `Error` events. By default errors are replaced with a `Completed` event but `Interrupted` can also be specified as `replacement`.

```swift
func ignoreError(#replacement: Event<T, NoError> = .Completed) -> Signal<T, NoError>
```

##### `timeoutAfter`
Forwards events from `signal` until it terminates or until `interval` time passes. This is nearly identical to `timeoutWithError` from RAC except any terminating `event` can be used for the timeout.

```swift
func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<T, E>, onScheduler scheduler: DateSchedulerType) -> Signal<T, E>
```

##### `uncollect`

Flattens batches of elements sent on `signal` into each individual element. The inverse of `collect`. Requires signal values to conform to `SequenceType`.

```swift
func uncollect() -> Signal<T.Generator.Element, E>
```


## SignalProducer
Operators specific to `SignalProducer`.

##### `groupBy`
Partitions values from `producer` into new producer groups based on the key returned from `grouping`. Termination events on the original producer are forwarded to each inner producer group.

```swift
func groupBy<K: Hashable>(grouping: T -> K) -> SignalProducer<(K, SignalProducer<T, E>), E>
```


## Property
Extensions for creating properties from signals. These are curried to support chaining with `|>`.

##### `propertyOf`
Creates a new property bound to the provided signal/producer starting with `initialValue`.

```swift
func propertyOf<T>(initialValue: T)(signal: Signal<T, NoError>) -> PropertyOf<T>
func propertyOf<T>(initialValue: T)(producer: SignalProducer<T, NoError>) -> PropertyOf<T>
```

##### `propertySink`
Wraps `sink` in a property bound to the provided signal/producer. Values sent on `signal` are `put` into the `sink` to update it.

```swift
func propertySink<S: SinkType>(sink: S)(signal: Signal<S.Element, NoError>) -> PropertyOf<S>
func propertySink<S: SinkType>(sink: S)(producer: SignalProducer<S.Element, NoError>) -> PropertyOf<S>
```


## License
Rex is released under the [MIT license](LICENSE)
