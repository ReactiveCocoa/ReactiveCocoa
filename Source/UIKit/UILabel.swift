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
    public var rex_text: MutableProperty<String?> {
        return associatedProperty(self, key: &attributedTextKey, initial: { $0.text }, setter: { $0.text = $1 })
    }
    
    /// Wraps a label's `attributedText` value in a bindable property.
    public var rex_attributedText: MutableProperty<NSAttributedString?> {
        return associatedProperty(self, key: &attributedTextKey, initial: { $0.attributedText }, setter: { $0.attributedText = $1 })
    }

    /// Wraps a label's `textColor` value in a bindable property.
    public var rex_textColor: MutableProperty<UIColor> {
        return associatedProperty(self, key: &textColorKey, initial: { $0.textColor }, setter: { $0.textColor = $1 })
    }
}

private var textKey: UInt8 = 0
private var attributedTextKey: UInt8 = 0
private var textColorKey: UInt8 = 0
