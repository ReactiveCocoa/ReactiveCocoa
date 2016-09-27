//
//  UILabel.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension UILabel {
	/// Wraps a label's `text` value in a bindable property.
	public var rac_text: BindingTarget<String?> {
		return bindingTarget { $0.text = $1 }
	}

	/// Wraps a label's `attributedText` value in a bindable property.
	public var rac_attributedText: BindingTarget<NSAttributedString?> {
		return bindingTarget { $0.attributedText = $1 }
	}

	/// Wraps a label's `textColor` value in a bindable property.
	public var rac_textColor: BindingTarget<UIColor> {
		return bindingTarget { $0.textColor = $1 }
	}
}
