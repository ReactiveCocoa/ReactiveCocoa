import ReactiveSwift
import UIKit
import enum Result.NoError

public protocol ReactiveControlConfigurable: class {
	static var defaultControlEvents: UIControlEvents { get }
}

public protocol ReactiveContinuousControlConfigurable: ReactiveControlConfigurable {
	static var defaultContinuousControlEvents: UIControlEvents { get }
}

extension Reactive where Base: UIControl {
    internal func makeActionBindable<U>(for controlEvent: UIControlEvents, _ transform: @escaping (Base) -> U) -> ActionBindable<Base, U> {
		return ActionBindable(owner: base,
		                      isEnabled: \.isEnabled,
		                      values: { $0.reactive.mapControlEvents(controlEvent, transform) })
	}

	internal func makeValueBindable<U>(
		value: ReferenceWritableKeyPath<Base, U>,
		values: @escaping (Base) -> Signal<U, NoError>,
		actionDidBind: ((Base, ActionStates, CompositeDisposable) -> Void)? = nil
	) -> ValueBindable<Base, U> {
		return ValueBindable(owner: base,
		                     isEnabled: \.isEnabled,
		                     value: value,
		                     values: { values($0) },
		                     actionDidBind: actionDidBind)
	}
}

// The following subscripts override the one in NSObject+BindingTarget.

extension Reactive where Base: UIControl & ReactiveControlConfigurable {
	/// Creates a value bindable with the given writable key path.
	///
	/// - parameters:
	///   - keyPath: The key path to bind with.
	///   - controlEvents: The control events which the bindable should react to.
	///
	/// - returns: A value bindable.
	internal subscript<Value>(
		keyPath: ReferenceWritableKeyPath<Base, Value>
	) -> ValueBindable<Base, Value> {
		return makeValueBindable(value: keyPath,
								 values: { $0.reactive.map(keyPath) })
	}

	/// Create a signal which sends the value pointed by the given key path upon every
	/// occurence of the default control events of the control.
	///
	/// - parameters:
	///   - keyPath: A key path of the control.
	///
	/// - returns: A signal that sends the value of the control.
	public func map<Value>(_ keyPath: KeyPath<Base, Value>) -> Signal<Value, NoError> {
		return mapControlEvents(Base.defaultControlEvents, { $0[keyPath: keyPath] })
	}
}

extension Reactive where Base: UIControl & ReactiveContinuousControlConfigurable {
	/// Creates a continuous value bindable with the given writable key path.
	///
	/// - parameters:
	///   - keyPath: The key path to bind with.
	///   - controlEvents: The control events which the bindable should react to.
	///
	/// - returns: A value bindable.
	internal subscript<Value>(
		continuous keyPath: ReferenceWritableKeyPath<Base, Value>
	) -> ValueBindable<Base, Value> {
		return makeValueBindable(value: keyPath,
								 values: { $0.reactive.continuousMap(keyPath) })
	}

	/// Create a signal which sends the value pointed by the given key path upon every
	/// occurence of the default continuous control events of the control.
	///
	/// - parameters:
	///   - keyPath: A key path of the control.
	///
	/// - returns: A signal that sends the value of the control.
	public func continuousMap<Value>(_ keyPath: KeyPath<Base, Value>) -> Signal<Value, NoError> {
		return mapControlEvents(Base.defaultContinuousControlEvents, { $0[keyPath: keyPath] })
	}
}

extension Reactive where Base: UIControl {
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
	public func controlEvents(_ controlEvents: UIControlEvents) -> Signal<Base, NoError> {
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
	public func mapControlEvents<Value>(_ controlEvents: UIControlEvents, _ transform: @escaping (Base) -> Value) -> Signal<Value, NoError> {
		return Signal { observer in
			let receiver = CocoaTarget(observer) { transform($0 as! Base) }
			base.addTarget(receiver,
			               action: #selector(receiver.invoke),
			               for: controlEvents)

			let disposable = lifetime.ended.observeCompleted(observer.sendCompleted)

			return AnyDisposable { [weak base = self.base] in
				disposable?.dispose()

				base?.removeTarget(receiver,
				                   action: #selector(receiver.invoke),
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
