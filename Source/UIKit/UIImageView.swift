//
//  UIImageView.swift
//  Rex
//
//  Created by Andy Jacobs on 21/10/15.
//  Copyright © 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIImageView {
    /// Wraps a imageView's `image` value in a bindable property.
    public var rex_image: MutableProperty<UIImage?> {
        return associatedProperty(self, key: &imageKey, initial: { $0.image }, setter: { $0.image = $1 })
    }
    
    /// Wraps a imageView's `highlightedImage` value in a bindable property.
    public var rex_highlightedImage: MutableProperty<UIImage?> {
        return associatedProperty(self, key: &highlightedImageKey, initial: { $0.highlightedImage }, setter: { $0.highlightedImage = $1 })
    }
}

private var imageKey: UInt8 = 0
private var highlightedImageKey: UInt8 = 0
