# Debugging Techniques

This document lists debugging techniques and infrastructure helpful for debugging ReactiveCocoa applications.

#### Unscrambling Swift compiler errors

Type inferrence can be a source of hard-to-debug compiler errors. There are two potential places to be wrong when type inferrence used:

1. Definition of type inferred variable
2. Consumption of type inferred variable

In both cases errors are related to incorrect assumptions about type. Such issues are common for ReactiveCocoa applications as it is all about operations over data and related types. The current state of the Swift compiler can cause misleading type errors, especially when error happens in the middle of a signal chain. 

Below is an example of type-error scenario:

```
SignalProducer<Int, NoError>(value:42)
    .on(next: { answer in
        return _
    })
    .startWithCompleted {
        print("Completed.")
    }
```

The code above will not compile with the following error on a `print` call `error: ambiguous reference to member 'print'
print("Completed.")` To find the actual source of errors signal chains need to be broken apart. Add explicit definitions of closure types on each of the steps:

```
let initialProducer = SignalProducer<Int, NoError>.init(value:42)
let sideEffectProducer = initialProducer.on(next: { (answer: Int) in
    return _
})
let disposable = sideEffectProducer.startWithCompleted {
    print("Completed.")
}
```

The code above will not compile too, but with the error `error: cannot convert value of type '(_) -> _' to expected argument type '(Int -> ())?'` on definition of `on` closure. This gives enough of information to locate unexpected `return _` since `on` closure should not have any return value.
