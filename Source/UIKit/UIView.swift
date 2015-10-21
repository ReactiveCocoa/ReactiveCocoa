//
//  UIView.swift
//  Rex
//
//  Created by Andy Jacobs on 21/10/15.
//  Copyright © 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIView {
    /// Wraps a view's `alpha` value in a bindable property.
    public var rex_alpha: MutableProperty<CGFloat> {
        return rex_valueProperty(&alpha, { [weak self] in self?.alpha ?? 1.0 }, { [weak self] in self?.alpha = $0 })
    }
    
    /// Wraps a view's `hidden` state in a bindable property.
    public var rex_hidden: MutableProperty<Bool> {
        return rex_valueProperty(&hidden, { [weak self] in self?.hidden ?? false }, { [weak self] in self?.hidden = $0 })
    }
}

private var alpha: UInt8 = 0
private var hidden: UInt8 = 0