//
//  UIControl+EnableSendActionsForControlEvents.swift
//  Rex
//
//  Created by David Rodrigues on 24/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import UIKit

/// Unfortunately, there's an apparent limitation in using `sendActionsForControlEvents`
/// on unit-tests for any control besides `UIButton` which is very unfortunate since we
/// want test our bindings for `UIDatePicker`, `UISwitch`, `UITextField` and others
/// in the future. To be able to test them, we're now using swizzling to manually invoke
/// the pair target+action.
extension UIControl {

    public override class func initialize() {

        struct Static {
            static var token: dispatch_once_t = 0
        }

        if self !== UIControl.self {
            return
        }

        dispatch_once(&Static.token) {

            let originalSelector = #selector(UIControl.sendAction(_:to:forEvent:))
            let swizzledSelector = #selector(UIControl.rex_sendAction(_:to:forEvent:))

            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

            let didAddMethod = class_addMethod(self,
                                               originalSelector,
                                               method_getImplementation(swizzledMethod),
                                               method_getTypeEncoding(swizzledMethod))

            if didAddMethod {
                class_replaceMethod(self,
                                    swizzledSelector,
                                    method_getImplementation(originalMethod),
                                    method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }

    // MARK: - Method Swizzling

    func rex_sendAction(action: Selector, to target: AnyObject?, forEvent event: UIEvent?) {
        target?.performSelector(action, withObject: self)
    }
}
