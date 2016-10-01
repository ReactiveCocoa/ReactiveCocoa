//
//  UILabel.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactivity where Reactant: UILabel {
	/// Wraps a label's `text` value in a bindable property.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// Wraps a label's `attributedText` value in a bindable property.
	public var attributedText: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedText = $1 }
	}

	/// Wraps a label's `textColor` value in a bindable property.
	public var textColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.textColor = $1 }
	}
}
