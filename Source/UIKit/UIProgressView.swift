//
//  UIProgressView.swift
//  Rex
//
//  Created by Tomi Pajunen on 04/05/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIProgressView {
    /// Wraps a progressView's `progress` value in a bindable property.
    public var rex_progress: MutableProperty<Float> {
        return associatedProperty(self, key: &progressKey, initial: { $0.progress }, setter: { $0.progress = $1 })
    }
}

private var progressKey: UInt8 = 0