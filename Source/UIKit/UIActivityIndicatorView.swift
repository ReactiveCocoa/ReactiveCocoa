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

    /// Returns whether the receiver is animating.
    /// `true` if the receiver is animating, otherwise `false`.
    ///
    /// Setting the value of this property to `true` starts animation of the progress indicator,
    /// and setting it to `false` stops animation.
    public var animating: Bool {
        get {
            return isAnimating()
        }
        set {
            if newValue {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }

    /// Wraps an indicator's `animating` state in a bindable property.
    public var rex_animating: MutableProperty<Bool> {
        return associatedProperty(self, key: &animatingKey, initial: { $0.animating }, setter: { $0.animating = $1 })
    }

}

private var animatingKey: UInt8 = 0
