//
//  UIView.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit
import enum Result.NoError

private class UnsafeControlReceiver<Control: UIControl>: NSObject {
	private let observer: Observer<Control, NoError>

	fileprivate init(observer: Observer<Control, NoError>) {
		self.observer = observer
	}

	@objc fileprivate func sendNext(_ receiver: Any?) {
		observer.send(value: receiver as! Control)
	}
}

extension Reactivity where Reactant: UIControl {
	public func trigger(for events: UIControlEvents) -> Signal<Reactant, NoError> {
		return Signal { observer in
			let receiver = UnsafeControlReceiver(observer: observer)
			reactant.addTarget(receiver, action: #selector(UnsafeControlReceiver.sendNext), for: events)

			let disposable = reactant.rac.lifetime.ended.observeCompleted(observer.sendCompleted)

			return ActionDisposable { [weak reactant] in
				disposable?.dispose()
				reactant?.removeTarget(receiver, action: #selector(UnsafeControlReceiver.sendNext), for: events)
			}
		}
	}

	#if os(iOS)
	/// Creates a bindable property to wrap a control's value.
	///
	/// This property uses `UIControlEvents.ValueChanged` and `UIControlEvents.EditingChanged`
	/// events to detect changes and keep the value up-to-date.
	//
	internal func value<T>(getter: @escaping (Reactant) -> T, setter: @escaping (Reactant, T) -> ()) -> MutableProperty<T> {
		return associatedProperty(reactant, key: &valueChangedKey, initial: getter, setter: setter) { property in
			property <~ self.trigger(for: [.valueChanged, .editingChanged]).map(getter)
		}
	}
	#endif

	/// Wraps a control's `enabled` state in a bindable property.
	public var isEnabled: BindingTarget<Bool> {
		return bindingTarget { $0.isEnabled = $1 }
	}

	/// Wraps a control's `selected` state in a bindable property.
	public var isSelected: BindingTarget<Bool> {
		return bindingTarget { $0.isSelected = $1 }
	}

	/// Wraps a control's `highlighted` state in a bindable property.
	public var isHighlighted: BindingTarget<Bool> {
		return bindingTarget { $0.isHighlighted = $1 }
	}
}

private var valueChangedKey: UInt8 = 0
