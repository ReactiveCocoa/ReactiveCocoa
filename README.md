# Rex [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
Additional operators for [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa) that may not fit in the core framework.

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

## SignalProducer
Operators specific to `SignalProducer`.

##### `groupBy`
Partitions values from `producer` into new producer groups based on the key returned from `grouping`. Termination events on the original producer are forwarded to each inner producer group.

```swift
func groupBy<K: Hashable, T, E>(grouping: T -> K)(producer: SignalProducer<T, E>)
  -> SignalProducer<(K, SignalProducer<T, E>), E>
```

## License
Rex is released under the [MIT license](LICENSE)
