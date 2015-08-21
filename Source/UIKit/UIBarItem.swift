//
//  UIBarItem.swift
//  Rex
//
//  Created by Bjarke Hesthaven Søndergaard on 24/07/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIBarItem {
    /// Wraps a UIBarItem's `enabled` state in a bindable property.
    public var rex_enabled: MutableProperty<Bool> {
        return associatedProperty(self, &enabled, { [weak self] in self?.enabled ?? true }, { [weak self] in self?.enabled = $0 })
    }
}

private var enabled: UInt8 = 0
