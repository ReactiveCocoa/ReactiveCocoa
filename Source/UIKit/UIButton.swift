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
    public var rac_pressed: MutableProperty<CocoaAction> {
        return associatedObject(self, &pressed, { _ in
            let initial = CocoaAction.rex_disabled
            let property = MutableProperty(initial)

            property.producer
                |> combinePrevious(initial)
                |> start { previous, next in
                    self.removeTarget(previous, action: CocoaAction.selector, forControlEvents: .TouchUpInside)
                    self.addTarget(next, action: CocoaAction.selector, forControlEvents: .TouchUpInside)
            }

            self.rex_enabled <~ property.producer |> flatMap(.Latest) { $0.rex_enabledProducer }
            return property
        })
    }
}

private var pressed: UInt8 = 0