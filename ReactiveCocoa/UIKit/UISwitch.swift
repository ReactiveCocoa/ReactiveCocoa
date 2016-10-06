//
//  UISwitch.swift
//  Rex
//
//  Created by David Rodrigues on 07/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UISwitch {
	/// Wraps a switch's `on` value in a bindable property.
	public var isOn: BindingTarget<Bool> {
		return makeBindingTarget { $0.isOn = $1 }
	}

	public var isOnValues: Signal<Bool, NoError> {
		return trigger(for: .valueChanged).map { [unowned base] in base.isOn }
	}
}
