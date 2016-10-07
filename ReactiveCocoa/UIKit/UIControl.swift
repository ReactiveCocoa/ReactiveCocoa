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

	@objc fileprivate func sendNext(_ receiver: Any?) {
		observer.send(value: ())
	}
}

extension Reactive where Base: UIControl {
	internal var associatedAction: Atomic<(action: CocoaAction<Base>, controlEvents: UIControlEvents, disposable: Disposable)?> {
		return associatedObject(base,
		                        key: &associatedActionKey,
		                        initial: { _ in Atomic(nil) })
	}

	internal func setAction(_ action: CocoaAction<Base>?, for controlEvents: UIControlEvents) {
		associatedAction.modify { associatedAction in
			if let old = associatedAction {
				old.disposable.dispose()
			}

			if let action = action {
				base.addTarget(action, action: CocoaAction<Base>.selector, for: controlEvents)

				let disposable = CompositeDisposable()
				disposable += isEnabled <~ action.isEnabled
				disposable += { [weak base] in
					base?.removeTarget(action, action: CocoaAction<Base>.selector, for: controlEvents)
				}

				associatedAction = (action, controlEvents, ScopedDisposable(disposable))
			} else {
				associatedAction = nil
			}
		}
	}

	public func trigger(for controlEvents: UIControlEvents) -> Signal<(), NoError> {
		return Signal { observer in
			let receiver = UnsafeControlReceiver(observer: observer)
			base.addTarget(receiver,
			                   action: #selector(UnsafeControlReceiver.sendNext),
			                   for: controlEvents)

			let disposable = lifetime.ended.observeCompleted(observer.sendCompleted)

			return ActionDisposable { [weak base] in
				disposable?.dispose()

				base?.removeTarget(receiver,
				                   action: #selector(UnsafeControlReceiver.sendNext),
				                   for: controlEvents)
			}
		}
	}

	/// Wraps a control's `enabled` state in a bindable property.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}

	/// Wraps a control's `selected` state in a bindable property.
	public var isSelected: BindingTarget<Bool> {
		return makeBindingTarget { $0.isSelected = $1 }
	}

	/// Wraps a control's `highlighted` state in a bindable property.
	public var isHighlighted: BindingTarget<Bool> {
		return makeBindingTarget { $0.isHighlighted = $1 }
	}
}

private var associatedActionKey = 0
