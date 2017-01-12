import ReactiveSwift
import UIKit
import enum Result.NoError

extension Reactive where Base: UIControl {
	/// The current associated action of `self`, with its registered event mask
	/// and its disposable.
	internal var associatedAction: Atomic<(action: CocoaAction<Base>, controlEvents: UIControlEvents, disposable: Disposable)?> {
		return associatedValue { _ in Atomic(nil) }
	}

	/// Set the associated action of `self` to `action`, and register it for the
	/// control events specified by `controlEvents`.
	///
	/// - parameters:
	///   - action: The action to be associated.
	///   - controlEvents: The control event mask.
	///	  - disposable: An outside disposable that will be bound to the scope of
	///					the given `action`.
	internal func setAction(_ action: CocoaAction<Base>?, for controlEvents: UIControlEvents, disposable: Disposable? = nil) {
		associatedAction.modify { associatedAction in
			associatedAction?.disposable.dispose()

			if let action = action {
				base.addTarget(action, action: CocoaAction<Base>.selector, for: controlEvents)

				let compositeDisposable = CompositeDisposable()
				compositeDisposable += isEnabled <~ action.isEnabled
				compositeDisposable += { [weak base = self.base] in
					base?.removeTarget(action, action: CocoaAction<Base>.selector, for: controlEvents)
				}
				compositeDisposable += disposable

				associatedAction = (action, controlEvents, ScopedDisposable(compositeDisposable))
			} else {
				associatedAction = nil
			}
		}
	}

	/// Create a signal which sends a `value` event for each of the specified
	/// control events.
	///
	/// - parameters:
	///   - controlEvents: The control event mask.
	///
	/// - returns:
	///   A signal that sends the control each time the control event occurs.
	public func controlEvents(_ controlEvents: UIControlEvents) -> Signal<Base, NoError> {
		return Signal { observer in
			let receiver = CocoaTarget(observer) { $0 as! Base }
			base.addTarget(receiver,
			               action: #selector(receiver.sendNext),
			               for: controlEvents)

			let disposable = lifetime.ended.observeCompleted(observer.sendCompleted)

			return ActionDisposable { [weak base = self.base] in
				disposable?.dispose()

				base?.removeTarget(receiver,
				                   action: #selector(receiver.sendNext),
				                   for: controlEvents)
			}
		}
	}

	@available(*, unavailable, renamed: "controlEvents(_:)")
	public func trigger(for controlEvents: UIControlEvents) -> Signal<(), NoError> {
		fatalError()
	}

	/// Sets whether the control is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}

	/// Sets whether the control is selected.
	public var isSelected: BindingTarget<Bool> {
		return makeBindingTarget { $0.isSelected = $1 }
	}

	/// Sets whether the control is highlighted.
	public var isHighlighted: BindingTarget<Bool> {
		return makeBindingTarget { $0.isHighlighted = $1 }
	}
}
