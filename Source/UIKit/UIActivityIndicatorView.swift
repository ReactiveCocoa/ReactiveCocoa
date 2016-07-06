//
//  UIActivityIndicatorView.swift
//  Rex
//
//  Created by Evgeny Kazakov on 02/07/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIActivityIndicatorView {

    /// Wraps an indicator's `isAnimating()` state in a bindable property.
    /// Setting a new value to the property would call `startAnimating()` or
    /// `stopAnimating()` depending on the value.
    public var rex_animating: MutableProperty<Bool> {
        return associatedProperty(self, key: &animatingKey, initial: { $0.isAnimating() }, setter: { host, animating in
            if animating {
                host.startAnimating()
            } else {
                host.stopAnimating()
            }
        })
    }

}

private var animatingKey: UInt8 = 0
