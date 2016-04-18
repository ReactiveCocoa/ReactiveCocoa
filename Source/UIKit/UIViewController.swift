//
//  UIViewController.swift
//  Rex
//
//  Created by Rui Peres on 14/04/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import Result
import ReactiveCocoa
import UIKit

extension UIViewController {
    
    public typealias DismissingCompletion = (Void -> Void)?
    public typealias DismissingInformation = (animated: Bool, completion: DismissingCompletion)?
    
    /// Wraps a viewController's `dismissViewControllerAnimated` function in a bindable property.
    /// It mimics the same input as `dismissViewControllerAnimated`: a `Bool` flag for the animation
    /// and a `(Void -> Void)?` closure for `completion`.
    /// E.g:
    /// ```
    /// //Dismissed with animation (`true`) and `nil` completion
    /// viewController.rex_dismissAnimated <~ aProducer.map { _ in (true, nil) }
    /// ```
    /// The dismissal observation can be made either with binding (example above)
    /// or `viewController.dismissViewControllerAnimated(true, completion: nil)`
    public var rex_dismissAnimated: MutableProperty<DismissingInformation> {
        
        let initial: UIViewController -> DismissingInformation = { _ in nil }
        let setter: (UIViewController, DismissingInformation) -> Void = { host, dismissingInfo in
            
            guard let unwrapped = dismissingInfo else { return }
            host.dismissViewControllerAnimated(unwrapped.animated, completion: unwrapped.completion)
        }
        
        let property = associatedProperty(self, key: &dismissModally, initial: initial, setter: setter)
        
        property <~ rac_signalForSelector(#selector(UIViewController.dismissViewControllerAnimated(_:completion:)))
            .takeUntilBlock { _ in property.value != nil }
            .rex_toTriggerSignal()
            .map { _ in return nil }

        
        return property
    }
}

private var dismissModally: UInt8 = 0