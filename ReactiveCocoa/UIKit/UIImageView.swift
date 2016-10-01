//
//  UIImageView.swift
//  Rex
//
//  Created by Andy Jacobs on 21/10/15.
//  Copyright © 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactivity where Reactant: UIImageView {
	/// Wraps a imageView's `image` value in a bindable property.
	public var image: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.image = $1 }
	}

	/// Wraps a imageView's `highlightedImage` value in a bindable property.
	public var highlightedImage: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.highlightedImage = $1 }
	}
}
