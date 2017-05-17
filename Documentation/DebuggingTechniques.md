# Debugging Techniques

This document lists debugging techniques and infrastructure helpful for debugging ReactiveCocoa applications.

#### Use of unresolved operator '<~' or <Class> not found in RAC 5

Since the split into ReactiveCocoa and ReactiveSwift, you'll need to `import ReactiveSwift` as well when using classes or operators that are implemented in ReactiveSwift.

#### Unscrambling Swift compiler errors

Type inferrence can be a source of hard-to-debug compiler errors. There are two potential places to be wrong when type inferrence used:

1. Definition of type inferred variable
2. Consumption of type inferred variable

In both cases errors are related to incorrect assumptions about type. Such issues are common for ReactiveCocoa applications as it is all about operations over data and related types. The current state of the Swift compiler can cause misleading type errors, especially when error happens in the middle of a signal chain. 

Below is an example of type-error scenario:

```swift
SignalProducer<Int, NoError>(value:42)
    .on(value: { answer in
        return _
    })
    .startWithCompleted {
        print("Completed.")
    }
```

The code above will not compile with the following error on the `.startWithCompleted` call `error: cannot convert value of type 'Disposable' to closure result type '()'. To find the actual compile error, the chain needs to be broken apart. Add explicit definitions of closure types on each of the steps:

```swift
let initialProducer = SignalProducer<Int, NoError>.init(value:42)
let sideEffectProducer = initialProducer.on(value: { (answer: Int) in
    return _
})
let disposable = sideEffectProducer.startWithCompleted {
    print("Completed.")
}
```

The code above will not compile too, but with the error `error: cannot convert value of type '(Int) -> _' to expected argument type '((Int) -> Void)?'` on definition of `on` closure. This gives enough of information to locate unexpected `return _` since `on` closure should not have any return value.

#### Debugging event streams

As mentioned in the README, stream debugging can be quite difficut and tedious, so we provide the `logEvents` operator. In its  simplest form:

```swift
let searchString = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
    .logEvents()
```

This will print to the standard output the events. For most use cases, this is enough and will greatly help you understand your flow. 
The biggest problem with this approach, is that it will continue to ouput in Release mode. This leaves with you with two options:

1. Comment out the operator: `//.logEvents()`. This is the simpleste approach, but it's error prone, since you will eventually forget to do this.
2. Pass your own function and manipulate the output as you see fit. This is the recommended approach.

Let's see how this would look like if we didn't want to print in Release mode:

```swift
func debugLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
   // Don't forget to set up the DEBUG symbol (http://stackoverflow.com/a/24112024/491239)
   #if DEBUG
      print(event)
   #endif
}
```

You would then:

```swift
let searchString = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
    .logEvents(logger: debugLog)
```

We also provide the `identifier` parameter. This is useful when you are debugging multiple streams and you don't want to get lost:

```swift
let searchString = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
    .logEvents(identifier: "✨My awesome stream ✨")
```

There also cases, especially with [hot signals][Signal], when there is simply too much output. For those, you can specify which events you are interested in:

```swift
let searchString = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
    .logEvents(events: [.disposed])
```

[Signal]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Signal.swift

