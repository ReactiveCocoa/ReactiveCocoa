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

private class UnsafeControlReceiver: NSObject {
	private let observer: Observer<(), NoError>

	fileprivate init(observer: Observer<(), NoError>) {
		self.observer = observer
	}

	@objc fileprivate func sendNext() {
		observer.send(value: ())
	}
}

extension UIControl {
	public func trigger(for events: UIControlEvents) -> Signal<(), NoError> {
		return Signal { observer in
			let receiver = UnsafeControlReceiver(observer: observer)
			addTarget(receiver, action: #selector(UnsafeControlReceiver.sendNext), for: events)

			let disposable = rac_lifetime.ended.observeCompleted(observer.sendCompleted)

			return ActionDisposable { [weak self] in
				disposable?.dispose()
				self?.removeTarget(receiver, action: #selector(UnsafeControlReceiver.sendNext), for: events)
			}
		}
	}

	#if os(iOS)
	/// Creates a bindable property to wrap a control's value.
	///
	/// This property uses `UIControlEvents.ValueChanged` and `UIControlEvents.EditingChanged`
	/// events to detect changes and keep the value up-to-date.
	//
	class func rac_value<Host: UIControl, T>(_ host: Host, getter: @escaping (Host) -> T, setter: @escaping (Host, T) -> ()) -> MutableProperty<T> {
		return associatedProperty(host, key: &valueChangedKey, initial: getter, setter: setter) { property in
			property <~
				host.trigger(for: [.valueChanged, .editingChanged])
					.map { [unowned host] in getter(host) }
		}
	}
	#endif

	/// Wraps a control's `enabled` state in a bindable property.
	public var rac_enabled: BindingTarget<Bool> {
		return bindingTarget { $0.isEnabled = $1 }
	}

	/// Wraps a control's `selected` state in a bindable property.
	public var rac_selected: BindingTarget<Bool> {
		return bindingTarget { $0.isSelected = $1 }
	}

	/// Wraps a control's `highlighted` state in a bindable property.
	public var rac_highlighted: BindingTarget<Bool> {
		return bindingTarget { $0.isHighlighted = $1 }
	}
}

private var valueChangedKey: UInt8 = 0
