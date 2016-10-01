//
//  UIActivityIndicatorView.swift
//  Rex
//
//  Created by Evgeny Kazakov on 02/07/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactivity where Reactant: UIActivityIndicatorView {

	/// Wraps an indicator's `isAnimating()` state in a bindable property.
	/// Setting a new value to the property would call `startAnimating()` or
	/// `stopAnimating()` depending on the value.
	public var isAnimating: BindingTarget<Bool> {
		return makeBindingTarget { _self, isAnimating in
			if isAnimating {
				_self.startAnimating()
			} else {
				_self.stopAnimating()
			}
		}
	}
}
