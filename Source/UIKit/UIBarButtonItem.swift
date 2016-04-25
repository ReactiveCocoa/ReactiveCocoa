//
//  UIBarButtonItem.swift
//  Rex
//
//  Created by Bjarke Hesthaven Søndergaard on 24/07/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIBarButtonItem {
    /// Exposes a property that binds an action to bar button item. The action is set as
    /// a target of the button. When property changes occur the previous action is
    /// overwritten. This also binds the enabled state of the action to the `rex_enabled`
    /// property on the button.
    public var rex_action: MutableProperty<CocoaAction> {
        return associatedObject(self, key: &actionKey) { host in
            let initial = CocoaAction.rex_disabled
            let property = MutableProperty(initial)
            
            property.producer
                .startWithNext { [weak host] action in
                    host?.target = action
                    host?.action = CocoaAction.selector
                }

            host.rex_enabled <~ property.producer.flatMap(.Latest) { $0.rex_enabledProducer }

            return property
        }
    }
}

private var actionKey: UInt8 = 0
