//
//  UIButton.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension UIButton {
	/// Exposes a property that binds an action to button presses. The action is set as
	/// a target of the button for `TouchUpInside` events. When property changes occur the
	/// previous action is removed as a target. This also binds the enabled state of the
	/// action to the `rac_enabled` property on the button.
	public var rac_pressed: MutableProperty<CocoaAction> {
		return associatedObject(self, key: &pressedKey) { host in
			let initial = CocoaAction.disabled
			let property = MutableProperty(initial)

			property.producer
				.combinePrevious(initial)
				.startWithValues { [weak host] previous, next in
					host?.removeTarget(previous, action: CocoaAction.selector, for: .touchUpInside)
					host?.addTarget(next, action: CocoaAction.selector, for: .touchUpInside)
				}

			host.rac_enabled <~ property.flatMap(.latest) { $0.isEnabled }

			return property
		}
	}

	/// Wraps a button's `title` text in a bindable property. Note that this only applies
	/// to `UIControlState.Normal`.
	public var rac_title: BindingTarget<String> {
		return bindingTarget { $0.setTitle($1, for: .normal) }
	}
}

private var pressedKey: UInt8 = 0
