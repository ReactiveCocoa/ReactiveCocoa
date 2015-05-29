# Rex [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
Extensions for [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) that may not fit in the core framework.

## Signal
All `Signal` operators can also be lifted to`SignalProducer`.

##### `filterMap`
Applies `transform` to values from `signal` with non-nil results unwrapped and forwared on the returned signal. This is equivalent to `map { … } |> filter { $0 != nil } |> map { $0! }`  but without creating extra intermediate signals.

```swift
func filterMap<T, U, E>(transform: T -> U?)(signal: Signal<T, E>) -> Signal<U, E>
```

##### `ignoreError`
Wraps a `signal` in a version that drops `Error` events. By default errors are replaced with a `Completed` event but `Interrupted` can also be specified as `replacement`.

```swift
func ignoreError<T, E>(signal: Signal<T, E>) -> Signal<T, NoError>
func ignoreError<T, E>(#replacement: Event<T, NoError>)(signal: Signal<T, E>) -> Signal<T, NoError>
```

##### `timeoutAfter`
Forwards events from `signal` until it terminates or until `interval` time passes. This is nearly identical to `timeoutWithError` from RAC except any terminating `event` can be used for the timeout.

```swift
func timeoutAfter<T, E>(interval: NSTimeInterval, withEvent event: Event<T, E>, onScheduler scheduler: DateSchedulerType) -> Signal<T, E> -> Signal<T, E>
```

##### `uncollect`

Flattens batches of elements sent on `signal` into each individual element. The inverse of `collect`.

```swift
func uncollect<S: SequenceType, E>(signal: Signal<S, E>) -> Signal<S.Generator.Element, E>
```


## SignalProducer
Operators specific to `SignalProducer`.

##### `groupBy`
Partitions values from `producer` into new producer groups based on the key returned from `grouping`. Termination events on the original producer are forwarded to each inner producer group.

```swift
func groupBy<K: Hashable, T, E>(grouping: T -> K)(producer: SignalProducer<T, E>)
  -> SignalProducer<(K, SignalProducer<T, E>), E>
```


## Property
Extensions for creating properties from signals. These are curried to support chaining with `|>` and lifting signal producers.

##### `propertyOf`
Creates a new property bound to `signal` starting with `initialValue`.

```swift
func propertyOf<T>(initialValue: T)(signal: Signal<T, NoError>) -> PropertyOf<T>
```

##### `propertySink`
Wraps `sink` in a property bound to `signal`. Values sent on `signal` are `put` into the `sink` to update it.

```swift
func sinkProperty<S: SinkType>(sink: S)(signal: Signal<S.Element, NoError>) -> PropertyOf<S>
```


## License
Rex is released under the [MIT license](LICENSE)
