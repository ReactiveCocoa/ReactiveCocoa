//
//  UIProgressView.swift
//  Rex
//
//  Created by Tomi Pajunen on 04/05/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactive where Base: UIProgressView {
	/// Wraps a progressView's `progress` value in a bindable property.
	public var progress: BindingTarget<Float> {
		return makeBindingTarget { $0.progress = $1 }
	}
}
