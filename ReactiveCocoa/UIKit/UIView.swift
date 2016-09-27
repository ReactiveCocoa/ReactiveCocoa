//
//  UIView.swift
//  Rex
//
//  Created by Andy Jacobs on 21/10/15.
//  Copyright © 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension UIView {
	/// Wraps a view's `alpha` value in a bindable property.
	public var rac_alpha: BindingTarget<CGFloat> {
		return bindingTarget { $0.alpha = $1 }
	}

	/// Wraps a view's `hidden` state in a bindable property.
	public var rac_hidden: BindingTarget<Bool> {
		return bindingTarget { $0.isHidden = $1 }
	}


	/// Wraps a view's `userInteractionEnabled` state in a bindable property.
	public var rac_userInteractionEnabled: BindingTarget<Bool> {
		return bindingTarget { $0.isUserInteractionEnabled = $1 }
	}
}
