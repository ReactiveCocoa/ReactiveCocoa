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

    /// Wraps a switch's `on` state in a bindable property.
    public var rex_on: MutableProperty<Bool> {

        let property = associatedProperty(self, key: &onKey, initial: { $0.on }, setter: { $0.on = $1 })

        property <~ rex_controlEvents(.ValueChanged)
            .filterMap { ($0 as? UISwitch)?.on }

        return property
    }
    
}

private var onKey: UInt8 = 0
