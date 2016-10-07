//
//  UITextField.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UITextField {
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	public var textValues: Signal<String?, NoError> {
		return trigger(for: .editingDidEnd).map { [unowned base] in base.text }
	}

	public var continuousTextValues: Signal<String?, NoError> {
		return trigger(for: .editingChanged).map { [unowned base] in base.text }
	}
}
