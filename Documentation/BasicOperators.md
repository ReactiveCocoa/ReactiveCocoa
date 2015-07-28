# Basic Operators

This document explains some of the most common operators used in ReactiveCocoa,
and includes examples demonstrating their use.

Note that “operators,” in this context, refers to functions that transform
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

  1. [Concatenating](#concatenating)
  1. [Merging](#merging)
  1. [Switching to the latest](#switching-to-the-latest)

**[Handling errors](#handling-errors)**

  1. [Catching errors](#catch)
  1. [Mapping errors](#mapping-error)
  1. [Retrying](#retrying)

## Performing side effects with event streams

### Observation

`Signal`s can be observed with the `observe` function. It takes an `Observer` as argument to which any future events are sent. 

```Swift
signal.observe(Signal.Observer { event in
    switch event {
    case let .Next(next):
        println("Next: \(next)")
    case let .Error(error):
        println("Error: \(error)")
    case .Completed:
        println("Completed")
    case .Interrupted:
        println("Interrupted")
    }
})
```

Alternatively, callbacks for the `Next`, `Error`, `Completed` and `Interrupted` events can be provided which will be called when a corresponding event occurs.

```Swift
signal.observe(next: { next in
    println("Next: \(next)")
}, error: { error in
    println("Error: \(error)")
}, completed: {
    println("Completed")
}, interrupted: {
    println("Interrupted")
})
```

Note that it is not necessary to provide all four parameters - all of them are optional, you only need to provide callbacks for the events you care about.

### Injecting effects

Side effects can be injected on a `SignalProducer` with the `on` operator without actually subscribing to it. 

```Swift
let producer = signalProducer
    .on(started: {
        println("Started")
    }, event: { event in
        println("Event: \(event)")
    }, error: { error in
        println("Error: \(error)")
    }, completed: {
        println("Completed")
    }, interrupted: {
        println("Interrupted")
    }, terminated: {
        println("Terminated")
    }, disposed: {
        println("Disposed")
    }, next: { next in
        println("Next: \(next)")
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

The `map` operator is used to transform the values in a event stream, creating
a new stream with the results.

```Swift
let (signal, sink) = Signal<String, NoError>.pipe()

signal
    .map { string in string.uppercaseString }
    .observe(next: println)

sendNext(sink, "a")     // Prints A
sendNext(sink, "b")     // Prints B
sendNext(sink, "c")     // Prints C
```

[Interactive visualisation of the `map` operator.](http://neilpa.me/rac-marbles/#map)

### Filtering

The `filter` operator is used to only include values in an event stream that
satisfy a predicate.

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()

signal
    .filter { number in number % 2 == 0 }
    .observe(next: println)

sendNext(sink, 1)     // Not printed
sendNext(sink, 2)     // Prints 2
sendNext(sink, 3)     // Not printed
sendNext(sink, 4)     // prints 4
```

[Interactive visualisation of the `filter` operator.](http://neilpa.me/rac-marbles/#filter)

### Aggregating

The `reduce` operator is used to aggregate a event stream’s values into a single
combined value. Note that the final value is only sent after the input stream
completes.

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()

signal
    .reduce(1) { $0 * $1 }
    .observe(next: println)

sendNext(sink, 1)     // nothing printed
sendNext(sink, 2)     // nothing printed
sendNext(sink, 3)     // nothing printed
sendCompleted(sink)   // prints 6
```

The `collect` operator is used to aggregate a event stream’s values into
a single array value. Note that the final value is only sent after the input
stream completes.

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()
signal.collect().observe(next: println)

sendNext(sink, 1)     // nothing printed
sendNext(sink, 2)     // nothing printed
sendNext(sink, 3)     // nothing printed
sendCompleted(sink)   // prints [1, 2, 3]
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
let (numbersSignal, numbersSink) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersSink) = Signal<String, NoError>.pipe()

combineLatest(numbersSignal, lettersSignal)
    .observe(next: println, completed: { println("Completed") })

sendNext(numbersSink, 0)    // nothing printed
sendNext(numbersSink, 1)    // nothing printed
sendNext(lettersSink, "A")  // prints (1, A)
sendNext(numbersSink, 2)    // prints (2, A)
sendCompleted(numbersSink)  // nothing printed
sendNext(lettersSink, "B")  // prints (2, B)
sendNext(lettersSink, "C")  // prints (2, C)
sendCompleted(lettersSink)  // prints "Completed"
```

The `combineLatestWith` operator works in the same way, but as an operator.

[Interactive visualisation of the `combineLatest` operator.](http://neilpa.me/rac-marbles/#combineLatest)

### Zipping

The `zip` function joins values of two (or more) event streams pair-wise. The
elements of any Nth tuple correspond to the Nth elements of the input streams.

That means the Nth value of the output stream cannot be sent until each input
has sent at least N values.

```Swift
let (numbersSignal, numbersSink) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersSink) = Signal<String, NoError>.pipe()

zip(numbersSignal, lettersSignal)
    .observe(next: println, completed: { println("Completed") })

sendNext(numbersSink, 0)    // nothing printed
sendNext(numbersSink, 1)    // nothing printed
sendNext(lettersSink, "A")  // prints (0, A)
sendNext(numbersSink, 2)    // nothing printed
sendCompleted(numbersSink)  // nothing printed
sendNext(lettersSink, "B")  // prints (1, B)
sendNext(lettersSink, "C")  // prints (2, C) & "Completed"

```

The `zipWith` operator works in the same way, but as an operator.

[Interactive visualisation of the `zip` operator.](http://neilpa.me/rac-marbles/#zip)

## Flattening producers

The `flatten` operator transforms a `SignalProducer`-of-`SignalProducer`s into a single `SignalProducer` whose values are forwarded from the inner producer in accordance with the provided `FlattenStrategy`.

To understand, why there are different strategies and how they compare to each other, take a look at this example and imagine the column offsets as time:

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

The `.Merge` strategy immediately forwards every value of the inner `SignalProducer`s to the outer `SignalProducer`. Any error sent on the outer producer or any inner producer is immediately sent on the flattened producer and terminates it.

```Swift
let (producerA, lettersSink) = SignalProducer<String, NoError>.buffer(5)
let (producerB, numbersSink) = SignalProducer<String, NoError>.buffer(5)
let (signal, sink) = SignalProducer<SignalProducer<String, NoError>, NoError>.buffer(5)

signal.flatten(.Merge).start(next: println)

sendNext(sink, producerA)
sendNext(sink, producerB)
sendCompleted(sink)

sendNext(lettersSink, "a")    // prints "a"
sendNext(numbersSink, "1")    // prints "1"
sendNext(lettersSink, "b")    // prints "b"
sendNext(numbersSink, "2")    // prints "2"
sendNext(lettersSink, "c")    // prints "c"
sendNext(numbersSink, "3")    // prints "3"
```

[Interactive visualisation of the `flatten(.Merge)` operator.](http://neilpa.me/rac-marbles/#merge)

### Concatenating

The `.Concat` strategy is used to serialize work of the inner `SignalProducer`s. The outer producer is started immediately. Each subsequent producer is not started until the preceeding one has completed. Errors are immediately forwarded to the flattened producer.

```Swift
let (producerA, lettersSink) = SignalProducer<String, NoError>.buffer(5)
let (producerB, numbersSink) = SignalProducer<String, NoError>.buffer(5)
let (signal, sink) = SignalProducer<SignalProducer<String, NoError>, NoError>.buffer(5)

signal.flatten(.Concat).start(next: println)

sendNext(sink, producerA)
sendNext(sink, producerB)
sendCompleted(sink)

sendNext(numbersSink, "1")    // nothing printed
sendNext(lettersSink, "a")    // prints "a"
sendNext(lettersSink, "b")    // prints "b"
sendNext(numbersSink, "2")    // nothing printed
sendNext(lettersSink, "c")    // prints "c"
sendCompleted(lettersSink)    // prints "1", "2"
sendNext(numbersSink, "3")    // prints "3"
sendCompleted(numbersSink)
```

[Interactive visualisation of the `flatten(.Concat)` operator.](http://neilpa.me/rac-marbles/#concat)

### Switching to the latest

The `.Latest` strategy forwards only values from the latest input `SignalProducer`.

```Swift
let (producerA, sinkA) = SignalProducer<String, NoError>.buffer(5)
let (producerB, sinkB) = SignalProducer<String, NoError>.buffer(5)
let (producerC, sinkC) = SignalProducer<String, NoError>.buffer(5)
let (signal, sink) = SignalProducer<SignalProducer<String, NoError>, NoError>.buffer(5)

signal.flatten(.Latest).start(next: println)

sendNext(sink, producerA)   // nothing printed
sendNext(sinkC, "X")        // nothing printed
sendNext(sinkA, "a")        // prints "a"
sendNext(sinkB, "1")        // nothing printed
sendNext(sink, producerB)   // prints "1"
sendNext(sinkA, "b")        // nothing printed
sendNext(sinkB, "2")        // prints "2"
sendNext(sinkC, "Y")        // nothing printed
sendNext(sinkA, "c")        // nothing printed
sendNext(sink, producerC)   // prints "X", "Y"
sendNext(sinkB, "3")        // nothing printed
sendNext(sinkC, "Z")        // prints "Z"
```

## Handling errors

These operators are used to handle errors that might occur on an event stream.

### Catching errors

The `catch` operator catches any error that may occur on the input `SignalProducer`, then starts a new `SignalProducer` in its place.

```Swift
let (producer, sink) = SignalProducer<String, NSError>.buffer(5)
let error = NSError(domain: "domain", code: 0, userInfo: nil)

producer
    .catch { error in SignalProducer<String, NSError>(value: "Default") }
    .start(next: println)


sendNext(sink, "First")     // prints "First"
sendNext(sink, "Second")    // prints "Second"
sendError(sink, error)      // prints "Default"
```

### Retrying

The `retry` operator will restart the original `SignalProducer` on error up to `count` times.

```Swift
var tries = 0
let limit = 2
let error = NSError(domain: "domain", code: 0, userInfo: nil)
let producer = SignalProducer<String, NSError> { (sink, _) in
    if tries++ < limit {
        sendError(sink, error)
    } else {
        sendNext(sink, "Success")
        sendCompleted(sink)
    }
}

producer
    .on(error: {e in println("Error")})             // prints "Error" twice
    .retry(2)
    .start(next: println,                           // prints "Success"
          error: { _ in println("Signal Error")})
```

If the `SignalProducer` does not succeed after `count` tries, the resulting `SignalProducer` will fail. E.g., if  `retry(1)` is used in the example above instead of `retry(2)`, `"Signal Error"` will be printed instead of `"Success"`.

### Mapping errors

The `mapError` operator transforms any error in an event stream into a new error. 

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

let (signal, sink) = Signal<String, NSError>.pipe()

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
    .observe(error: println)

sendError(sink, NSError(domain: "com.example.foo", code: 42, userInfo: nil))    // prints "Foo Error"
```

### Promote

The `promoteErrors` operator promotes an event stream that does not generate errors into one that can. 

```Swift
let (numbersSignal, numbersSink) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersSink) = Signal<String, NSError>.pipe()

numbersSignal
    .promoteErrors(NSError)
    .combineLatestWith(lettersSignal)
```

The given stream will still not _actually_ generate errors, but this is useful
because some operators to [combine streams](#combining-event-streams) require
the inputs to have matching error types.


[Signals]: FrameworkOverview.md#signals
[Signal Producers]: FrameworkOverview.md#signal-producers
[Observation]: FrameworkOverview.md#observation

