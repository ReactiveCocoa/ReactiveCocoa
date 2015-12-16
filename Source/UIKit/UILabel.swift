//
//  UILabel.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UILabel {
    /// Wraps a label's `text` value in a bindable property.
    public var rex_text: MutableProperty<String> {
        return associatedProperty(self, keyPath: "text")
    }

    /// Wraps a label's `textColor` value in a bindable property.
    public var rex_textColor: MutableProperty<UIColor> {
        return associatedProperty(self, key: &textColor, initial: { $0.textColor }, setter: { $0.textColor = $1 })
    }
}
