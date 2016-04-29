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

#### Binding `DynamicProperty` with `<~` operator

Using the `<~` operator to bind a `Signal` or a `SignalProducer` to a `DynamicProperty` can result in unexpected compiler errors. 

Below is an example of this scenario:

```swift
let label = UILabel()
let property = MutableProperty<String>("")

DynamicProperty(object: label, keyPath: "text") <~ property.producer
```

This will often result in a compiler error: 

> error: binary operator '<~' cannot be applied to operands of type 'DynamicProperty' and 'SignalProducer<String, NoError>'
DynamicProperty(object: label, keyPath: "text") <~ property.producer

The reason is a limitation in the swift type checker - A `DynamicProperty` always has a type of `AnyObject?`, but the `<~` operator requires the values of both sides to have the same type, so the right side value would have to be `AnyObject?` as well, but usually a more concrete type is used (in this example `String`).

Usually, the fix is as easy as adding a `.map{ $0 }`.

```swift
DynamicProperty(object: label, keyPath: "text") <~ property.producer.map { $0 }
```

This allows the type checker to infer that `String` can be converted to `AnyProperty?` and thus, the binding succeeds.