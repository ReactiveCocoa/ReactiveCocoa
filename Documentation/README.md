# ReactiveSwift

ReactiveCocoa is based on ReactiveSwift and extends ReactiveSwift by Cocoa (esp. UIKit and AppKit) specific aspects. 

For documentation of the basics, please refer to the [ReactiveSwift Documentation][ReactiveSwiftDocumentation]. Specifically, you can find documentation about

* [Framework Overview][]
* [Basic Operators][]
* [Design Guidelines][]

This document outlines the additions that ReactiveCocoa brings over ReactiveSwift.

# Additions in ReactiveCocoa

## Foundation: Object Interception

ReactiveCocoa includes a few object interception tools from ReactiveObjC, remastered for use with Swift.
    
1. **Method Call Interception**

    Create signals that are sourced by intercepting Objective-C objects.
    
    ```swift
    // Notify after every time `viewWillAppear(_:)` is called.
    let appearing = viewController.reactive.trigger(for: #selector(UIViewController.viewWillAppear(_:)))
    ```
    
1. **Object Lifetime**

    Obtain a `Lifetime` token for any `NSObject` to observe their deinitialization.

    ```swift
    // Observe the lifetime of `object`.
    object.reactive.lifetime.ended.observeCompleted(doCleanup)
    ```

1. **Dynamic Property**
    
    The [`DynamicProperty`][] type can be used to bridge to Objective-C APIs that require Key-Value Coding (KVC) or Key-Value Observing (KVO), like `NSOperation`. Note that most AppKit and UIKit properties do _not_ support KVO, so their changes should be observed through other mechanisms.
    
    
    For binding UI, [UIKit][UIKit-bindings] and [AppKit](AppKit-bindings) bindings provided by ReactiveCocoa are preferred.
    In all other cases, [`MutableProperty`][] should be preferred over dynamic properties whenever possible!

1. **Expressive, Safe Key Path Observation**

    Establish key-value observations in the form of [`SignalProducer`][]s and
    strong-typed [`DynamicProperty`][]s, and enjoy the inherited composability.
    
    ```swift
    // A producer that sends the current value of `keyPath`, followed by
    // subsequent changes.
    //
    // Terminate the KVO observation if the lifetime of `self` ends.
    let producer = object.reactive.values(forKeyPath: #keyPath(key))
        .take(during: self.reactive.lifetime)
    
    // A parameterized property that represents the supplied key path of the
    // wrapped object. It holds a weak reference to the wrapped object.
    let property = DynamicProperty<String>(object: person,
                                           keyPath: #keyPath(person.name))
    ```

    These are accessible via the `reactive` magic property that is available on any ObjC objects.

## UI Bindings

ReactiveCocoa provides UI bindings for UIKit and AppKit via the `reactive` structure.

1. **BindingTarget**

    UI components expose [`BindingTarget`][]s, which accept bindings from any
    kind of streams of values via the `<~` operator.

    ```swift
    // Bind the `name` property of `person` to the text value of an `UILabel`.
    nameLabel.reactive.text <~ person.name
    ```

1. **Controls and User Interactions**

    Interactive UI components expose [`Signal`][]s for control events
    and updates in the control value upon user interactions.
    
    A selected set of controls provide a convenience, expressive binding
    API for [`Action`][]s.
    
    ```swift
    // Update `allowsCookies` whenever the toggle is flipped.
    preferences.allowsCookies <~ toggle.reactive.isOnValues 
    
    // Compute live character counts from the continuous stream of user initiated
    // changes in the text.
    textField.reactive.continuousTextValues.map { $0.characters.count }
    
    // Trigger `commit` whenever the button is pressed.
    button.reactive.pressed = CocoaAction(viewModel.commit)
    ```
    
    These are accessible via the `reactive` magic property that is available on any ObjC objects.
    
    CocoaAction wraps an Action for use by a GUI control (such as `NSControl` or `UIControl`), with KVO, or with Cocoa Bindings.

[ReactiveSwiftDocumentation]: https://github.com/ReactiveCocoa/ReactiveSwift/tree/master/Documentation
[Framework Overview]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md
[Basic Operators]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/BasicOperators.md
[Design Guidelines]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/DesignGuidelines.md
[`Signal`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#signals
[`SignalProducer`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#signal-producers
[`Action`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#actions
[`BindingTarget`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/FrameworkOverview.md#properties
[`MutableProperty`]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Property.swift#L583
[`DynamicProperty`]: https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/ReactiveCocoa/DynamicProperty.swift
[UIKit-bindings]: https://github.com/ReactiveCocoa/ReactiveCocoa/tree/master/ReactiveCocoa/UIKit
[AppKit-bindings]: https://github.com/ReactiveCocoa/ReactiveCocoa/tree/master/ReactiveCocoa/AppKit
