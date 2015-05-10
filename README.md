## Rex
Additional operators for ReactiveCocoa

### Signal operators
Note that all `Signal` operators can also be lifted to`SignalProducer`.

##### `filterMap`
Applies `transform` to values from `signal` with non-nil results unwrapped and forwared on the returned signal. This is equivalent to `signal |> map { … } |> filter { $0 != nil } |> map { $0! }`  but doesn't create intermediate signals.

```swift
func filterMap<T, U, E>(transform: T -> U?)(signal: Signal<T, E>) -> Signal<U, E>
```

### SignalProducer operators

##### `groupBy`
Buckets each received value into a group based on the key returned from `grouping`. Termination events on the original signal are also forwarded to each producer group.

```swift
func groupBy<K: Hashable, T, E>(grouping: T -> K)(producer: SignalProducer<T, E>)
  -> SignalProducer<(K, SignalProducer<T, E>), E>
```
