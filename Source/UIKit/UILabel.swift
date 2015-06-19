//
//  UILabel.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

extension UILabel {
    /// Wraps a label's `enabled` state in a bindable property.
    public var rex_text: MutableProperty<String> {
        return associatedProperty(self, "text")
    }
}