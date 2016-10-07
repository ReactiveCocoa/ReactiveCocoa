//
//  UIActivityIndicatorView.swift
//  Rex
//
//  Created by Evgeny Kazakov on 02/07/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactive where Base: UIActivityIndicatorView {
	/// Sets whether the activity indicator should be animating.
	public var isAnimating: BindingTarget<Bool> {
		return makeBindingTarget { $1 ? $0.startAnimating() : $0.stopAnimating() }
	}
}
