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
    
    public typealias Completion = (Void -> Void)?
    public typealias DismissingInformation = (Bool, Completion)?
    public var rex_dismissModally: MutableProperty<DismissingInformation> {
        
        let initial: UIViewController -> DismissingInformation = { _ in nil }
        let setter: (UIViewController, DismissingInformation) -> Void = { host, dismissingInfo in
            
            guard let unwrapped = dismissingInfo else { return }
            host.dismissViewControllerAnimated(unwrapped.0, completion: unwrapped.1)
        }
        
        let property = associatedProperty(self, key: &dismissModally, initial: initial, setter: setter)

        return property
    }
}

private var dismissModally: UInt8 = 0