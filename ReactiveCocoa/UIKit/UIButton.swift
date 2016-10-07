//
//  UIButton.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactive where Base: UIButton {
	public var pressed: CocoaAction<Base>? {
		get {
			return associatedAction.withValue { info in
				return info.flatMap { info in
					return info.controlEvents == .touchUpInside ? info.action : nil
				}
			}
		}

		nonmutating set {
			setAction(newValue, for: .touchUpInside)
		}
	}

	/// Wraps a button's `title` text in a bindable property. Note that this only applies
	/// to `UIControlState.Normal`.
	public var title: BindingTarget<String> {
		return makeBindingTarget { $0.setTitle($1, for: .normal) }
	}

	/// Sets the title of the button for the specified state.
	public func title(for state: UIControlState) -> BindingTarget<String> {
		return makeBindingTarget { $0.setTitle($1, for: state) }
	}
}

private var pressedKey: UInt8 = 0
