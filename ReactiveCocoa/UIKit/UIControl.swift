import ReactiveSwift
import UIKit

extension Reactive where Base: UIControl {
	/// The current associated action of `self`, with its registered event mask
	/// and its disposable.
	internal var associatedAction: Atomic<(action: CocoaAction<Base>, controlEvents: UIControl.Event, disposable: Disposable)?> {
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
	internal func setAction(_ action: CocoaAction<Base>?, for controlEvents: UIControl.Event, disposable: Disposable? = nil) {
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
	/// - note: If you mean to observe the **value** of `self` with regard to a particular
	///         control event, `mapControlEvents(_:_:)` should be used instead.
	///
	/// - parameters:
	///   - controlEvents: The control event mask.
	///
	/// - returns: A signal that sends the control each time the control event occurs.
	public func controlEvents(_ controlEvents: UIControl.Event) -> Signal<Base, Never> {
		return mapControlEvents(controlEvents, { $0 })
	}

	/// Create a signal which sends a `value` event for each of the specified
	/// control events.
	///
	/// - important: You should use `mapControlEvents` in general unless the state of
	///              the control — e.g. `text`, `state` — is not concerned. In other
	///              words, you should avoid using `map` on a control event signal to
	///              extract the state from the control.
	///
	/// - note: For observations that could potentially manipulate the first responder
	///         status of `base`, `mapControlEvents(_:_:)` is made aware of the potential
	///         recursion induced by UIKit and would collect the values for the control
	///         events accordingly using the given transform.
	///
	/// - parameters:
	///   - controlEvents: The control event mask.
	///   - transform: A transform to reduce `Base`.
	///
	/// - returns: A signal that sends the reduced value from the control each time the
	///            control event occurs.
	public func mapControlEvents<Value>(_ controlEvents: UIControl.Event, _ transform: @escaping (Base) -> Value) -> Signal<Value, Never> {
		return Signal { observer, signalLifetime in
			let receiver = CocoaTarget(observer) { transform($0 as! Base) }
			base.addTarget(receiver,
			               action: #selector(receiver.invoke),
			               for: controlEvents)

			let disposable = lifetime.ended.observeCompleted(observer.sendCompleted)

			signalLifetime.observeEnded { [weak base] in
				disposable?.dispose()

				base?.removeTarget(receiver,
				                   action: #selector(receiver.invoke),
				                   for: controlEvents)
			}
		}
	}

	@available(*, unavailable, renamed: "controlEvents(_:)")
	public func trigger(for controlEvents: UIControl.Event) -> Signal<(), Never> {
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
