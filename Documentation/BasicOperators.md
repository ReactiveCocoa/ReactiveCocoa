# Basic Operators

This document explains some of the most common operators used in ReactiveCocoa,
and includes examples demonstrating their use. Note that operators in this context
refer to functions that transform signals, _not_ custom Swift operators. In other
words, these are the composeable primitives provided by ReactiveCocoa for working
with signals. Roughly speaking they take the shape of `(Input..., Signal...) -> Signal`.

Additionally, this document will use the term "signal" when dealing with concepts that
apply to both `Signal` and `SignalProducer`. When the distinction matters the inline
code-style will be used.

**[Performing side effects with signals](#performing-side-effects-with-signals)**

  1. [Observation](#observation)
  1. [Injecting effects](#injecting-effects)

**[Operator composition](#signal-operator-composition)**

  1. [Lifting](#lifting)
  1. [Pipe](#pipe)

**[Transforming signals](#transforming-signals)**

  1. [Mapping](#mapping)
  1. [Filtering](#filtering)
  1. [Reducing](#reducing)

**[Combining signals](#combining-signals)**

  1. [Combining latest values](#combining-latest-values)
  1. [Zipping](#zipping)

**[Flattening producers](#flattening-producers)**

  1. [Concatenating](#concatenating)
  1. [Merging](#merging)
  1. [Switching](#switching)

**[Handling errors](#handling-errors)**

  1. [Catching errors](#catch)
  1. [Mapping errors](#mapping-error)
  1. [Retrying](#retrying)

## Performing side effects with signals

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
    }
)
```

Note that it is not necessary to provide all four parameters - all of them are optional, you only need to provide callbacks for the events you care about.

`observe` is also available as operator that can be used with [|>](#pipe)

### Injecting effects

Side effects can be injected on a `SignalProducer` with the `on` operator without actually subscribing to it. 

```Swift
let producer = signalProducer
    |> on(started: {
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
Note, that nothing will be printed until `producer` is started (possibly somewhere else).

## Operator composition

### Pipe

The `|>` operator can be used to apply a signal operator to a signal. Multiple operators can be chained after each other using the `|>` operator

```Swift
intSignal
    |> filter { num in num % 2 == 0 }
    |> map(toString)
    |> observe(next: { string in println(string) })
```

### Lifting

Signal operators can be _lifted_ to operate upon `SignalProducer`s with the `lift` operator.
In other words, this will create a new `SignalProducer` which will apply the given signal operator to _every_ signal created from the incoming `SignalProducer`s just if the operator had been applied to each signal yielded from `start()`.

The `|>` operator implicitly lifts signal operators, when used with `SignalProducer`s.

## Transforming signals

These operators transform a signal into a new signal.

### Mapping

The `map` operator is used to transform the values in a signal, creating a new signal with the results.

```Swift
let (signal, sink) = Signal<String, NoError>.pipe()
signal
    |> map { string in string.uppercaseString }
    |> observe(next: { println($0) })

sendNext(sink, "a")     // Prints A
sendNext(sink, "b")     // Prints B
sendNext(sink, "c")     // Prints C
```


### Filtering

The `filter` operator is used to include only values in a signal that satisfy a predicate

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()
signal
    |> filter { number in number % 2 == 0 }
    |> observe(next: { println($0) })

sendNext(sink, 1)     // Not printed
sendNext(sink, 2)     // Prints 2
sendNext(sink, 3)     // Not printed
sendNext(sink, 4)     // prints 4
```

### Aggregating

The `reduce` operator is used to aggregate a signals value into a single combine value. Note, that the final value is only sent after the source signal completes.

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()

signal
    |> reduce(1) { $0 * $1 }
    |> observe(next: { println($0) })

sendNext(sink, 1)     // nothing printed
sendNext(sink, 2)     // nothing printed
sendNext(sink, 3)     // nothing printed
sendCompleted(sink)   // prints 6
```


## Combining signals

These operators combine values from multiple signals into a unified new signal.

### Combining latest values

The `combineLatest` function combines the latest values of two (or more) signals. The resulting signal will only send a the first value after both inputs have sent at least one value each. After that, each value on either of the inputs will cause a new value on the output.

```Swift
let (numbersSignal, numbersSink) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersSink) = Signal<String, NoError>.pipe()

combineLatest(numbersSignal, lettersSignal)
    |> observe(next: { println($0) }, completed: { println("Completed") })

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

### Zipping

The `zip` function combines values of two (or more) signals into pairs. The elements of any Nth pair are the Nth elements of the input signals. That means the output signal will always wait for all input signals to send and output.

```Swift
let (numbersSignal, numbersSink) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersSink) = Signal<String, NoError>.pipe()

zip(numbersSignal, lettersSignal)
    |> observe(next: { println($0) }, completed: { println("Completed") })

sendNext(numbersSink, 0)    // nothing printed
sendNext(numbersSink, 1)    // nothing printed
sendNext(lettersSink, "A")  // prints (0, A)
sendNext(numbersSink, 2)    // nothing printed
sendCompleted(numbersSink)  // nothing printed
sendNext(lettersSink, "B")  // prints (1, B)
sendNext(lettersSink, "C")  // prints (2, C) & "Completed"

```

The `zipWith` operator works in the same way, but as an operator.

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
let (numbersSignal, numbersSink) = SignalProducer<AnyObject, NoError>.buffer(5)
let (lettersSignal, lettersSink) = SignalProducer<AnyObject, NoError>.buffer(5)
let (signal, sink) = SignalProducer<SignalProducer<AnyObject, NoError>, NoError>.buffer(5)

signal
    |> flatten(FlattenStrategy.Merge)
    |> start(next: { println($0) })

sendNext(sink, numbersSignal)
sendNext(sink, lettersSignal)
sendCompleted(sink)

sendNext(numbersSink, 1)    // prints 1
sendNext(lettersSink, "A")  // prints A
sendNext(numbersSink, 2)    // prints 2
sendNext(lettersSink, "B")  // prints B
sendNext(numbersSink, 3)    // prints 3
sendNext(lettersSink, "C")  // prints C
```

### Concatenating

The `.Concat` strategy is used to serialize work of the inner `SignalProducer`s. The outer producer is started immediately. Each subsequent producer is not started until the preceeding one has completed. Errors are immediately forwarded to the flattened producer.

```Swift
let (numbersSignal, numbersSink) = SignalProducer<AnyObject, NoError>.buffer(5)
let (lettersSignal, lettersSink) = SignalProducer<AnyObject, NoError>.buffer(5)
let (signal, sink) = SignalProducer<SignalProducer<AnyObject, NoError>, NoError>.buffer(5)

signal
    |> flatten(FlattenStrategy.Concat)
    |> start(next: { println($0) })

sendNext(sink, numbersSignal)
sendNext(sink, lettersSignal)
sendCompleted(sink)

sendNext(numbersSink, 1)    // prints 1
sendNext(lettersSink, "A")  // nothing printed
sendNext(numbersSink, 2)    // prints 2
sendNext(lettersSink, "B")  // nothing printed
sendNext(numbersSink, 3)    // prints 3
sendNext(lettersSink, "C")  // nothing printed
sendCompleted(numbersSink)  // prints A, B, C
sendCompleted(lettersSink)
```

### Switching

The `.Latest` strategy forwards only values from the latest input `SignalProducer`.

```Swift
let (numbersSignal, numbersSink) = SignalProducer<AnyObject, NoError>.buffer(5)
let (lettersSignal, lettersSink) = SignalProducer<AnyObject, NoError>.buffer(5)
let (signal, sink) = SignalProducer<SignalProducer<AnyObject, NoError>, NoError>.buffer(5)

signal
    |> flatten(FlattenStrategy.Latest)
    |> start(next: { println($0) })

sendNext(sink, numbersSignal)   // nothing printed
sendNext(numbersSink, 1)        // prints 1
sendNext(lettersSink, "A")      // nothing printed
sendNext(sink, lettersSignal)   // prints A
sendNext(numbersSink, 2)        // nothing printed
sendNext(lettersSink, "B")      // prints B
sendNext(numbersSink, 3)        // nothing printed
sendNext(lettersSink, "C")      // prints C
```

## Handling errors

These operators are used to handle errors that might occur on a signal.

### Catching errors

The `catch` operator catches any error that may occur on the input `SignalProducer`, then starts a new `SignalProducer` in its place.

```Swift
let (signalA, sinkA) = SignalProducer<String, NSError>.buffer(5)
let (signalB, sinkB) = SignalProducer<String, NSError>.buffer(5)

signalA
    |> catch { error in signalB }
    |> start(next: { println($0)})

let error = NSError(domain: "domain", code: 0, userInfo: nil)

sendNext(sinkA, "A")        // prints A
sendNext(sinkB, "a")        // nothing printed
sendError(sinkA, error)     // prints a
sendNext(sinkA, "B")        // nothing printed
sendNext(sinkB, "b")        // prints b
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
    |> on(error: {e in println("Error")})             // prints "Error" twice
    |> retry(2)
    |> start(next: { println($0)},                    // prints "Success"
        error: { error in println("Signal Error")})
```

If the `SignalProducer` does not succeed after `count` tries, the resulting `SignalProducer` will fail. E.g., if  `retry(1)` is used in the example above instead of `retry(2)`, `"Signal Error"` will be printed instead of `"Success"`.

### Mapping errors

The `mapError` operator transforms errors in the signal to new errors. 

```Swift
struct CustomError: ErrorType {
    let code: Int
    
    init(_ code: Int) {
        self.code = code
    }
    
    var nsError: NSError {
        get {
            return NSError(domain: "domain", code: self.code, userInfo: nil)
        }
    }
}

let (signal, sink) = Signal<String, CustomError>.pipe()

signal
    |> mapError { $0.nsError }
    |> observe(error: {println($0)})

sendError(sink, CustomError(404))   // Prints NSError with code 404
```

### Promote

The `promoteErrors` operator promotes a signal that does not generate errors into one that can. 

```Swift
let (numbersSignal, numbersSink) = Signal<Int, NoError>.pipe()
let (lettersSignal, lettersSink) = Signal<String, NSError>.pipe()

numbersSignal
    |> promoteErrors(NSError)
    |> combineLatestWith(lettersSignal)
```

The given signal will still not actually generate errors, but some operators to [combine signals](#combining-signals) require the incoming signals to have matching error types.


[Signals]: FrameworkOverview.md#signals
[Signal Producers]: FrameworkOverview.md#signal-producers
[Observation]: FrameworkOverview.md#observation

