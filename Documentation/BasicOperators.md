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
### Injecting effects


## Operator composition

### Lifting
### Pipe


## Transforming signals

These operators transform a signal into a new signal.

### Mapping

The `map` operator is used to transform the values in a signal, creating a new signal with the results.

```Swift
let (signal, sink) = Signal<String, NoError>.pipe()
let mapped = signal |> map { string in
    string.uppercaseString
}

mapped.observe(next: { println($0) })

sendNext(sink, "a")     // Prints A
sendNext(sink, "b")     // Prints B
sendNext(sink, "c")     // Prints C
```


### Filtering

The `filter` operator is used to include only values in a signal that satisfy a predicate

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()
let filtered = signal |> filter { number in
    number % 2 == 0
}

filtered.observe(next: { println($0) })

sendNext(sink, 1)     // Not printed
sendNext(sink, 2)     // Prints 2
sendNext(sink, 3)     // Not printed
sendNext(sink, 4)     // prints 4
```

### Reducing

The `reduce` operator is used to aggregate a signals value into a signle combine value. Note, that the final value is only sended after the source signal completes.

```Swift
let (signal, sink) = Signal<Int, NoError>.pipe()
let filtered = signal |> reduce(1) { $0 * $1 }

filtered.observe(next: { println($0) })

sendNext(sink, 1)     // nothing printed
sendNext(sink, 2)     // nothing printed
sendNext(sink, 3)     // nothing printed
sendCompleted(sink)   // prints 6
```


## Combining signals

### Combining latest values
### Zipping


## Flattening producers

### Concatenating
### Merging
### Switching


## Handling errors

### Catching errors
### Mapping errors
### Retrying


[Signals]: FrameworkOverview.md#signals
[Signal Producers]: FrameworkOverview.md#signal-producers
[Observation]: FrameworkOverview.md#observation

