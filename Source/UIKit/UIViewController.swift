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
    /// Returns a `Signal`, that will be triggered
    /// when `self`'s `viewDidDisappear` is called
    public var rex_viewDidDisappear: Signal<(), NoError> {
        return triggerForSelector(#selector(UIViewController.viewDidDisappear(_:)))
    }
    
    /// Returns a `Signal`, that will be triggered
    /// when `self`'s `viewWillDisappear` is called
    public var rex_viewWillDisappear: Signal<(), NoError> {
        return triggerForSelector(#selector(UIViewController.viewWillDisappear(_:)))
    }
    
    /// Returns a `Signal`, that will be triggered
    /// when `self`'s `viewDidAppear` is called
    public var rex_viewDidAppear: Signal<(), NoError> {
        return triggerForSelector(#selector(UIViewController.viewDidAppear(_:)))
    }
    
    /// Returns a `Signal`, that will be triggered
    /// when `self`'s `viewWillAppear` is called
    public var rex_viewWillAppear: Signal<(), NoError> {
        return triggerForSelector(#selector(UIViewController.viewWillAppear(_:)))
    }
    
    private func triggerForSelector(selector: Selector) -> Signal<(), NoError>  {
        return self
            .rac_signalForSelector(selector)
            .rex_toTriggerSignal()
    }
    
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
        
        let property = associatedProperty(self, key: &dismissModally, initial: initial, setter: setter) { property in
            property <~ self.rac_signalForSelector(#selector(UIViewController.dismissViewControllerAnimated(_:completion:)))
                .takeUntilBlock { _ in property.value != nil }
                .rex_toTriggerSignal()
                .map { _ in return nil }
        }
        
        return property
    }
}

private var dismissModally: UInt8 = 0
