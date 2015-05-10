## Rex
Additional operators for ReactiveCocoa

### Signal operators
Note that all `Signal` operators can also be lifted to`SignalProducer`.

##### `filterMap`
Applies `transform` to values from `signal` with non-nil results unwrapped and forwared on the returned signal. This is equivalent to `map { … } |> filter { $0 != nil } |> map { $0! }`  but without creating extra intermediate signals.

```swift
func filterMap<T, U, E>(transform: T -> U?)(signal: Signal<T, E>) -> Signal<U, E>
```

### SignalProducer operators

##### `groupBy`
Partitions values from `producer` into new producer groups based on the key returned from `grouping`. Termination events on the original producer are forwarded to each inner producer group.

```swift
func groupBy<K: Hashable, T, E>(grouping: T -> K)(producer: SignalProducer<T, E>)
  -> SignalProducer<(K, SignalProducer<T, E>), E>
```
