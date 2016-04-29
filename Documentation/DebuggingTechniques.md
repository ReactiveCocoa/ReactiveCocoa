# Debugging Techniques

This document lists debugging techniques and infrastructure helpful for debugging ReactiveCocoa applications.

#### Unscrambling Swift compiler errors

Type inferrence can be a source of hard-to-debug compiler errors. There are two potential places to be wrong when type inferrence used:

1. Definition of type inferred variable
2. Consumption of type inferred variable

In both cases errors are related to incorrect assumptions about type. Such issues are common for ReactiveCocoa applications as it is all about operations over data and related types. The current state of the Swift compiler can cause misleading type errors, especially when error happens in the middle of a signal chain. 

Below is an example of type-error scenario:

```swift
SignalProducer<Int, NoError>(value:42)
    .on(next: { answer in
        return _
    })
    .startWithCompleted {
        print("Completed.")
    }
```

The code above will not compile with the following error on a `print` call `error: ambiguous reference to member 'print'
print("Completed.")`. To find the actual compile error, the chain needs to be broken apart. Add explicit definitions of closure types on each of the steps:

```swift
let initialProducer = SignalProducer<Int, NoError>.init(value:42)
let sideEffectProducer = initialProducer.on(next: { (answer: Int) in
    return _
})
let disposable = sideEffectProducer.startWithCompleted {
    print("Completed.")
}
```

The code above will not compile too, but with the error `error: cannot convert value of type '(_) -> _' to expected argument type '(Int -> ())?'` on definition of `on` closure. This gives enough of information to locate unexpected `return _` since `on` closure should not have any return value.

#### Debugging event streams

As mentioned in the README, stream debugging can be quite difficut and tedious, so we provide the `debug` operator. In its  simplest form:


```swift
let searchString = textField.rac_textSignal()
    .toSignalProducer()
    .map { text in text as! String }
    .throttle(0.5, onScheduler: QueueScheduler.mainQueueScheduler)
    .debug()
```

This will print to the standard output the events. For most use cases, this is enough and will greatly help you understand your flow. 
The biggest problem with this approach, is that it will continue to ouput in Release mode. This leaves with you with two options:

1. Comment out the operator: `//.debug()`. This is the simpleste approach, but it's error prone, since you will eventually forget to do this.
2. Use the `EventLogger` protocol and manipulate the output as you see fit. This is the recommended approach.


Let's see how we could leverage the `EventLogger` protocol, so we don't print in Release mode:

```swift
final class MyLogger: EventLogger {
    func logEvent(event: String) {
        // Don't forget to set up the DEBUG symbol (http://stackoverflow.com/a/24112024/491239)
        #if DEBUG
            print(event)
        #endif
    }
}

```

You would then:

```swift
let logger = MyLogger()

let searchString = textField.rac_textSignal()
    .toSignalProducer()
    .map { text in text as! String }
    .throttle(0.5, onScheduler: QueueScheduler.mainQueueScheduler)
    .debug(logger: logger)
```

Finally we also provide the `identifier` parameter. This is useful when you are debugging multiple streams and you don't want to get lost:

```swift
let searchString = textField.rac_textSignal()
    .toSignalProducer()
    .map { text in text as! String }
    .throttle(0.5, onScheduler: QueueScheduler.mainQueueScheduler)
    .debug("✨My awesome stream ✨")
```


