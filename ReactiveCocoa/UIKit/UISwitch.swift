//
//  UISwitch.swift
//  Rex
//
//  Created by David Rodrigues on 07/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension UISwitch {

    /// Wraps a switch's `on` value in a bindable property.
    public var rex_on: MutableProperty<Bool> {
        return UIControl.rex_value(self, getter: { $0.isOn }, setter: { $0.isOn = $1 })
    }
}
