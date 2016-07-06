//
//  UISwitch.swift
//  Rex
//
//  Created by David Rodrigues on 07/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UISwitch {

    /// Wraps a switch's `on` value in a bindable property.
    public var rex_on: MutableProperty<Bool> {
        return UIControl.rex_value(self, getter: { $0.on }, setter: { $0.on = $1 })
    }
}
