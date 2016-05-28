# Basic Operators

This document explains some of the most common operators used in ReactiveCocoa,
and includes examples demonstrating their use.

Note that “operators”, in this context, refers to functions that transform
[signals][] and [signal producers][], _not_ custom Swift operators. In other
words, these are composable primitives provided by ReactiveCocoa for working
with event streams.

This document will use the term “event stream” when dealing with concepts that
apply to both `Signal` and `SignalProducer`. When the distinction matters, the
types will be referred to by name.

**[Performing side effects with event streams](#performing-side-effects-with-event-streams)**

  1. [Observation](#observation)
  1. [Injecting effects](#injecting-effects)

**[Operator composition](#operator-composition)**

  1. [Lifting](#lifting)

**[Transforming event streams](#transforming-event-streams)**

  1. [Mapping](#mapping)
  1. [Filtering](#filtering)
  1. [Aggregating](#aggregating)

**[Combining event streams](#combining-event-streams)**

  1. [Combining latest values](#combining-latest-values)
  1. [Zipping](#zipping)

**[Flattening producers](#flattening-producers)**

  1. [Merging](#merging)
  1. [Concatenating](#concatenating)
  1. [Switching to the latest](#switching-to-the-latest)

**[Handling failures](#handling-failures)**

  1. [Catching failures](#catching-failures)
  1. [Retrying](#retrying)
  1. [Mapping errors](#mapping-errors)
  1. [Promote](#promote)

## Performing side effects with event streams

### Observation

`Signal`s can be observed with the `observe` function. It takes an `Observer` as argument to which any future events are sent. 

```Swift
signal.observe(Signal.Observer { event in
    switch event {
    case let .Next(next):
        print("Next: \(next)")
    case let .Failed(error):
        print("Failed: \(error)")
    case .Completed:
        print("Completed")
    case .Interrupted:
        print("Interrupted")
    }
})
```

Alternatively, callbacks for the `Next`, `Failed`, `Completed` and `Interrupted` events can be provided which will be called when a corresponding event occurs.

```Swift
signal.observeNext { next in 
  print("Next: \(next)") 
}
signal.observeFailed { error in
  print("Failed: \(error)")
}
signal.observeCompleted { 
  print("Completed") 
}
signal.observeInterrupted { 
  print("Interrupted")
}
```

Note that it is not necessary to observe all four types of event - all of them are optional, you only need to provide callbacks for the events you care about.

### Injecting effects

Side effects can be injected on a `SignalProducer` with the `on` operator without actually subscribing to it. 

```Swift
let producer = signalProducer
    .on(started: {
        print("Started")
    }, event: { event in
        print("Event: \(event)")
    }, failed: { error in
        print("Failed: \(error)")
    }, completed: {
        print("Completed")
    }, interrupted: {
        print("Interrupted")
    }, terminated: {
        print("Terminated")
    }, disposed: {
        print("Disposed")
    }, next: { value in
        print("Next: \(value)")
    })
```

Similar to `observe`, all the parameters are optional and you only need to provide callbacks for the events you care about.

Note that nothing will be printed until `producer` is started (possibly somewhere else).

## Operator composition

### Lifting

`Signal` operators can be _lifted_ to operate upon `SignalProducer`s using the
`lift` method.

This will create a new `SignalProducer` which will apply the given operator to
_every_ `Signal` created, just as if the operator had been applied to each
produced `Signal` individually.

## Transforming event streams

These operators transform an event stream into a new stream.

### Mapping

The `map` operator is used to transform the values in an event stream, creating
a new stream with the results.

```Swift
let (signal, observer) = Signal<String, NoError>.pipe()

signal
    .map { string in string.uppercaseString }
    .observeNext { next in print(next) }

observer.sendNext("a")     // Prints A
observer.sendNext("b")     // Prints B
observer.sendNext("c")     // Prints C
```

[Interactive visualisation of the `map` operator.](http://neilpa.me/rac-marbles/#map)

### Filtering

The `filter` operator is used to only include values in an event stream that
satisfy a predicate.

```Swift
let (signal, observer) = Signal<Int, NoError>.pipe()

signal
    .filter { number in number % 2 == 0 }
    .observeNext { next in print(next) }

observer.sendNext(1)     // Not printed
observer.sendNext(2)     // Prints 2
observer.sendNext(3)     // Not printed
observer.sendNext(4)     // prints 4
```

[Interactive visualisation of the `filter` operator.](http://neilpa.me/rac-marbles/#filter)

### Aggregating

The `reduce` operator is used to aggregate a event stream’s values into a single
combined value. Note that the final value is only sent after the input stream
completes.

```Swift
let (signal, observer) = Signal<Int, NoError>.pipe()

signal
    .reduce(1) { $0 * $1 }
    .observeNext { next in print(next) }

observer.sendNext(1)     // nothing printed
observer.sendNext(2)     // nothing printed
observer.sendNext(3)     // nothing printed
observer.sendCompleted()   // prints 6
```

The `collect` operator is used to aggregate a event stream’s values into
a single array value. Note that the final value is only sent after the input
stream completes.

```Swift
let (signal, observer) = Signal<Int, NoError>.pipe()

signal
    .collect()
    .observeNext { next in print(next) }

observer.sendNext(1)     // nothing printed
observer.sendNext(2)     // nothing printed
observer.sendNext(3)     // nothing printed
observer.sendCompleted()   // prints [1, 2, 3]
```

[Interactive visualisation of the `reduce` operator.](http://neilpa.me/rac-marbles/#reduce)

## Combining event streams

These operators combine values from multiple event streams into a new, unified
stream.

### Combining latest values

The `combineLatest` function combines the latest values of two (or more) event
streams.

The resulting stream will only send its first value after each input has sent at
least one value. After that, new values on any of the inputs will result in
a new value on the output.

```Swift
let (numbersSignal, numbersObserver) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersObserver) = Signal<String, NoError>.pipe()

let signal = combineLatest(numbersSignal, lettersSignal)
signal.observeNext { next in print("Next: \(next)") }
signal.observeCompleted { print("Completed") }

numbersObserver.sendNext(0)      // nothing printed
numbersObserver.sendNext(1)      // nothing printed
lettersObserver.sendNext("A")    // prints (1, A)
numbersObserver.sendNext(2)      // prints (2, A)
numbersObserver.sendCompleted()  // nothing printed
lettersObserver.sendNext("B")    // prints (2, B)
lettersObserver.sendNext("C")    // prints (2, C)
lettersObserver.sendCompleted()  // prints "Completed"
```

The `combineLatestWith` operator works in the same way, but as an operator.

[Interactive visualisation of the `combineLatest` operator.](http://neilpa.me/rac-marbles/#combineLatest)

### Zipping

The `zip` function joins values of two (or more) event streams pair-wise. The
elements of any Nth tuple correspond to the Nth elements of the input streams.

That means the Nth value of the output stream cannot be sent until each input
has sent at least N values.

```Swift
let (numbersSignal, numbersObserver) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersObserver) = Signal<String, NoError>.pipe()

let signal = zip(numbersSignal, lettersSignal)
signal.observeNext { next in print("Next: \(next)") }
signal.observeCompleted { print("Completed") }

numbersObserver.sendNext(0)      // nothing printed
numbersObserver.sendNext(1)      // nothing printed
lettersObserver.sendNext("A")    // prints (0, A)
numbersObserver.sendNext(2)      // nothing printed
numbersObserver.sendCompleted()  // nothing printed
lettersObserver.sendNext("B")    // prints (1, B)
lettersObserver.sendNext("C")    // prints (2, C) & "Completed"

```

The `zipWith` operator works in the same way, but as an operator.

[Interactive visualisation of the `zip` operator.](http://neilpa.me/rac-marbles/#zip)

## Flattening producers

The `flatten` operator transforms a stream-of-streams into a single stream - where values are forwarded from the inner stream in accordance with the provided `FlattenStrategy`. The flattened result becomes that of the outer stream type - i.e. a `SignalProducer`-of-`SignalProducer`s or `SignalProducer`-of-`Signal`s gets flattened to a `SignalProducer`, and likewise a `Signal`-of-`SignalProducer`s or `Signal`-of-`Signal`s gets flattened to a `Signal`.   

To understand why there are different strategies and how they compare to each other, take a look at this example and imagine the column offsets as time:

```Swift
let values = [
// imagine column offset as time
[ 1,    2,      3 ],
   [ 4,      5,     6 ],
         [ 7,     8 ],
]

let merge =
[ 1, 4, 2, 7,5, 3,8,6 ]

let concat = 
[ 1,    2,      3,4,      5,     6,7,     8]

let latest =
[ 1, 4,    7,     8 ]
```

Note, how the values interleave and which values are even included in the resulting array.


### Merging

The `.Merge` strategy immediately forwards every value of the inner `SignalProducer`s to the outer `SignalProducer`. Any failure sent on the outer producer or any inner producer is immediately sent on the flattened producer and terminates it.

```Swift
let (producerA, lettersObserver) = SignalProducer<String, NoError>.buffer(5)
let (producerB, numbersObserver) = SignalProducer<String, NoError>.buffer(5)
let (signal, observer) = SignalProducer<SignalProducer<String, NoError>, NoError>.buffer(5)

signal.flatten(.Merge).startWithNext { next in print(next) }

observer.sendNext(producerA)
observer.sendNext(producerB)
observer.sendCompleted()

lettersObserver.sendNext("a")    // prints "a"
numbersObserver.sendNext("1")    // prints "1"
lettersObserver.sendNext("b")    // prints "b"
numbersObserver.sendNext("2")    // prints "2"
lettersObserver.sendNext("c")    // prints "c"
numbersObserver.sendNext("3")    // prints "3"
```

[Interactive visualisation of the `flatten(.Merge)` operator.](http://neilpa.me/rac-marbles/#merge)

### Concatenating

The `.Concat` strategy is used to serialize work of the inner `SignalProducer`s. The outer producer is started immediately. Each subsequent producer is not started until the preceeding one has completed. Failures are immediately forwarded to the flattened producer.

```Swift
let (producerA, lettersObserver) = SignalProducer<String, NoError>.buffer(5)
let (producerB, numbersObserver) = SignalProducer<String, NoError>.buffer(5)
let (signal, observer) = SignalProducer<SignalProducer<String, NoError>, NoError>.buffer(5)

signal.flatten(.Concat).startWithNext { next in print(next) }

observer.sendNext(producerA)
observer.sendNext(producerB)
observer.sendCompleted()

numbersObserver.sendNext("1")    // nothing printed
lettersObserver.sendNext("a")    // prints "a"
lettersObserver.sendNext("b")    // prints "b"
numbersObserver.sendNext("2")    // nothing printed
lettersObserver.sendNext("c")    // prints "c"
lettersObserver.sendCompleted()    // prints "1", "2"
numbersObserver.sendNext("3")    // prints "3"
numbersObserver.sendCompleted()
```

[Interactive visualisation of the `flatten(.Concat)` operator.](http://neilpa.me/rac-marbles/#concat)

### Switching to the latest

The `.Latest` strategy forwards only values from the latest input `SignalProducer`.

```Swift
let (producerA, observerA) = SignalProducer<String, NoError>.buffer(5)
let (producerB, observerB) = SignalProducer<String, NoError>.buffer(5)
let (producerC, observerC) = SignalProducer<String, NoError>.buffer(5)
let (signal, observer) = SignalProducer<SignalProducer<String, NoError>, NoError>.buffer(5)

signal.flatten(.Latest).startWithNext { next in print(next) }

observer.sendNext(producerA)   // nothing printed
observerC.sendNext("X")        // nothing printed
observerA.sendNext("a")        // prints "a"
observerB.sendNext("1")        // nothing printed
observer.sendNext(producerB)   // prints "1"
observerA.sendNext("b")        // nothing printed
observerB.sendNext("2")        // prints "2"
observerC.sendNext("Y")        // nothing printed
observerA.sendNext("c")        // nothing printed
observer.sendNext(producerC)   // prints "X", "Y"
observerB.sendNext("3")        // nothing printed
observerC.sendNext("Z")        // prints "Z"
```

## Handling failures

These operators are used to handle failures that might occur on an event stream.

### Catching failures

The `flatMapError` operator catches any failure that may occur on the input `SignalProducer`, then starts a new `SignalProducer` in its place.

```Swift
let (producer, observer) = SignalProducer<String, NSError>.buffer(5)
let error = NSError(domain: "domain", code: 0, userInfo: nil)

producer
    .flatMapError { _ in SignalProducer<String, NoError>(value: "Default") }
    .startWithNext { next in print(next) }


observer.sendNext("First")     // prints "First"
observer.sendNext("Second")    // prints "Second"
observer.sendFailed(error)     // prints "Default"
```

### Retrying

The `retry` operator will restart the original `SignalProducer` on failure up to `count` times.

```Swift
var tries = 0
let limit = 2
let error = NSError(domain: "domain", code: 0, userInfo: nil)
let producer = SignalProducer<String, NSError> { (observer, _) in
    if tries++ < limit {
        observer.sendFailed(error)
    } else {
        observer.sendNext("Success")
        observer.sendCompleted()
    }
}

producer
    .on(failed: {e in print("Failure")})    // prints "Failure" twice
    .retry(2)
    .start { event in
        switch event {
        case let .Next(next):
            print(next)                     // prints "Success"
        case let .Failed(error):
            print("Failed: \(error)")
        case .Completed:
            print("Completed")
        case .Interrupted:
            print("Interrupted")
        }
    }
```

If the `SignalProducer` does not succeed after `count` tries, the resulting `SignalProducer` will fail. E.g., if  `retry(1)` is used in the example above instead of `retry(2)`, `"Signal Failure"` will be printed instead of `"Success"`.

### Mapping errors

The `mapError` operator transforms the error of any failure in an event stream into a new error.

```Swift
enum CustomError: String, ErrorType {
    case Foo = "Foo"
    case Bar = "Bar"
    case Other = "Other"
    
    var nsError: NSError {
        return NSError(domain: "CustomError.\(rawValue)", code: 0, userInfo: nil)
    }
    
    var description: String {
        return "\(rawValue) Error"
    }
}

let (signal, observer) = Signal<String, NSError>.pipe()

signal
    .mapError { (error: NSError) -> CustomError in
        switch error.domain {
        case "com.example.foo":
            return .Foo
        case "com.example.bar":
            return .Bar
        default:
            return .Other
        }
    }
    .observeFailed { error in
        print(error)
    }

observer.sendFailed(NSError(domain: "com.example.foo", code: 42, userInfo: nil))    // prints "Foo Error"
```

### Promote

The `promoteErrors` operator promotes an event stream that does not generate failures into one that can. 

```Swift
let (numbersSignal, numbersObserver) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersObserver) = Signal<String, NSError>.pipe()

numbersSignal
    .promoteErrors(NSError)
    .combineLatestWith(lettersSignal)
```

The given stream will still not _actually_ generate failures, but this is useful
because some operators to [combine streams](#combining-event-streams) require
the inputs to have matching error types.


[Signals]: FrameworkOverview.md#signals
[Signal Producers]: FrameworkOverview.md#signal-producers
[Observation]: FrameworkOverview.md#observation

