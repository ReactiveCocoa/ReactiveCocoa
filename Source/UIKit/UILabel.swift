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
        return rex_stringProperty("text")
    }
}
