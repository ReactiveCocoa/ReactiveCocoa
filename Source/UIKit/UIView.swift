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
    public typealias InstanceType = UIView

    /// Wraps a view's `alpha` value in a bindable property.
    public var rex_alpha: MutableProperty<CGFloat> {
        return rex_valueProperty(&alphaKey, { $0.alpha }, { $0.alpha = $1 })
    }
    
    /// Wraps a view's `hidden` state in a bindable property.
    public var rex_hidden: MutableProperty<Bool> {
        return rex_valueProperty(&hiddenKey, { $0.hidden }, { $0.hidden = $1 })
    }
}

private var alphaKey: UInt8 = 0
private var hiddenKey: UInt8 = 0
