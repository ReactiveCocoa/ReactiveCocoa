//
//  UIButton.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIButton {
    /// Exposes a property that binds an action to button presses. The action is set as
    /// a target of the button for `TouchUpInside` events. When property changes occur the
    /// previous action is removed as a target. This also binds the enabled state of the
    /// action to the `rex_enabled` property on the button.
    public var rex_pressed: MutableProperty<CocoaAction> {
        return associatedObject(self, key: &pressed, initial: { [weak self] _ in
            let initial = CocoaAction.rex_disabled
            let property = MutableProperty(initial)

            property.producer
                .combinePrevious(initial)
                .start(next: { previous, next in
                    self?.removeTarget(previous, action: CocoaAction.selector, forControlEvents: .TouchUpInside)
                    self?.addTarget(next, action: CocoaAction.selector, forControlEvents: .TouchUpInside)
                })

            if let strongSelf = self {
                strongSelf.rex_enabled <~ property.producer.flatMap(.Latest) { $0.rex_enabledProducer }
            }
            return property
        })
    }

    /// Wraps a button's `title` text in a bindable property. Note that this only applies
    /// to `UIControlState.Normal`.
    public var rex_title: MutableProperty<String> {
        return rex_valueProperty(&title, { [weak self] in self?.titleForState(.Normal) ?? "" }, { [weak self] in self?.setTitle($0, forState: .Normal) })
    }
}

private var pressed: UInt8 = 0
private var title: UInt8 = 0
