import ReactiveSwift
import Result

infix operator <~>: BindingPrecedence

// `ValueBindable` need not conform to `BindingSource`, since the expected public
// APIs for observing user interactions are still the signals named with plural nouns.

public struct ValueBindable<Owner: AnyObject, Value>: ActionBindableProtocol, BindingTargetProvider {
	fileprivate weak var owner: Owner?
	fileprivate let isEnabled: ReferenceWritableKeyPath<Owner, Bool>
	fileprivate let value: ReferenceWritableKeyPath<Owner, Value>
	fileprivate let values: (Owner) -> Signal<Value, NoError>
	fileprivate let actionDidBind: ((Owner, ActionStates, CompositeDisposable) -> Void)?

	public var bindingTarget: BindingTarget<Value> {
		let lifetime = owner.map(lifetime(of:)) ?? .empty
		return BindingTarget(on: UIScheduler(), lifetime: lifetime) { value in
			self.owner?[keyPath: self.value] = value
		}
	}

	public var actionBindable: ActionBindable<Owner, Value> {
		return ActionBindable(owner: owner, isEnabled: isEnabled, values: values, actionDidBind: actionDidBind)
	}

	public init(
		owner: Owner?,
		isEnabled: ReferenceWritableKeyPath<Owner, Bool>,
		value: ReferenceWritableKeyPath<Owner, Value>,
		values: @escaping (Owner) -> Signal<Value, NoError>,
		actionDidBind: ((Owner, ActionStates, CompositeDisposable) -> Void)? = nil
	) {
		self.owner = owner
		self.isEnabled = isEnabled
		self.value = value
		self.values = values
		self.actionDidBind = actionDidBind
	}
}

public struct ActionBindable<Owner: AnyObject, Value>: ActionBindableProtocol {
	fileprivate weak var owner: Owner?
	fileprivate let isEnabled: ReferenceWritableKeyPath<Owner, Bool>
	fileprivate let values: (Owner) -> Signal<Value, NoError>
	fileprivate let actionDidBind: ((Owner, ActionStates, CompositeDisposable) -> Void)?

	public var actionBindable: ActionBindable<Owner, Value> {
		return self
	}

	public init(
		owner: Owner?,
		isEnabled: ReferenceWritableKeyPath<Owner, Bool>,
		values: @escaping (Owner) -> Signal<Value, NoError>,
		actionDidBind: ((Owner, ActionStates, CompositeDisposable) -> Void)? = nil
	) {
		self.owner = owner
		self.isEnabled = isEnabled
		self.values = values
		self.actionDidBind = actionDidBind
	}
}

public protocol ActionBindableProtocol {
	associatedtype Owner: AnyObject
	associatedtype Value

	var actionBindable: ActionBindable<Owner, Value> { get }
}

public struct ActionStates {
	let isExecuting: SignalProducer<Bool, NoError>

	fileprivate init<Input, Output, Error>(scheduler: UIScheduler, action: Action<Input, Output, Error>) {
		isExecuting = action.isExecuting.producer.observe(on: scheduler)
	}
}

// MARK: Transformation.
extension ActionBindableProtocol {
	fileprivate func mapOutput<U>(_ transform: @escaping (Value) -> U) -> ActionBindable<Owner, U> {
		let bindable = actionBindable
		return ActionBindable(owner: bindable.owner,
		                      isEnabled: bindable.isEnabled,
		                      values: { bindable.values($0).map(transform) },
		                      actionDidBind: bindable.actionDidBind)
	}
}

// MARK: Binding implementation.

extension ValueBindable {
	fileprivate func bind<P: ComposableMutablePropertyProtocol>(to property: P) -> Disposable? where P.Value == Value {
		return owner.flatMap { owner in
			return property.withValue { current in
				let disposable = CompositeDisposable()
				let serialDisposable = SerialDisposable()
				let scheduler = UIScheduler()
				var isReplacing = false

				owner[keyPath: self.value] = current

				disposable += property.signal
					.observe { event in
						serialDisposable.inner = scheduler.schedule {
							guard !isReplacing else { return }

							switch event {
							case let .value(value):
								self.owner?[keyPath: self.value] = value
							case .completed:
								disposable.dispose()
							case .interrupted, .failed:
								fatalError("Unexpected event.")
							}
						}
					}

				// UI control always takes precedence over changes from the background
				// thread for now.
				//
				// We also take advantage of the fact that `Property` is synchronous to
				// use a boolean flag as a simple & efficient feedback loop breaker.

				disposable += values(owner)
					.observeValues { [weak property] value in
						guard let property = property else { return }

						isReplacing = true
						property.value = value
						serialDisposable.inner = nil
						isReplacing = false
					}

				property.lifetime += disposable
				ReactiveCocoa.lifetime(of: owner) += disposable

				return AnyDisposable(disposable.dispose)
			}
		}
	}
}

extension ActionBindableProtocol {
	fileprivate func bind<Output, Error>(to action: Action<Value, Output, Error>) -> Disposable? {
		let bindable = actionBindable
		return bindable.owner.flatMap { control in
			let disposable = CompositeDisposable()
			let scheduler = UIScheduler()

			disposable += bindable.values(control).observeValues { [weak action] value in
				action?.apply(value).start()
			}

			disposable += action.isEnabled.producer
				.observe(on: scheduler)
				.startWithValues { isEnabled in
					bindable.owner?[keyPath: bindable.isEnabled] = isEnabled
			}


			action.lifetime += disposable
			ReactiveCocoa.lifetime(of: control) += disposable

			bindable.actionDidBind?(control, ActionStates(scheduler: scheduler, action: action), disposable)

			return AnyDisposable(disposable.dispose)
		}
	}
}

// MARK: Value bindings

extension ComposableMutablePropertyProtocol {
	/// Create a value binding between `bindable` and `property`.
	///
	/// The binding would use the current value of `property` as the initial value. It
	/// would prefer changes initiated on the main queue by `bindable`.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// heaterSwitch.reactive.isOn <~> viewModel.isHeaterTurnedOn
	/// viewModel.isHeaterTurnedOn <~> heaterSwitch.reactive.isOn
	/// ```
	///
	/// - parameters:
	///   - property: The property to bind with.
	///   - bindable: The value bindable to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the value binding.
	@discardableResult
	public static func <~> <Owner>(property: Self, bindable: ValueBindable<Owner, Value>) -> Disposable? {
		return bindable <~> property
	}
}

extension ValueBindable {
	/// Create a value binding between `bindable` and `property`.
	/// 
	/// The binding would use the current value of `property` as the initial value. It 
	/// would prefer changes initiated on the main queue by `bindable`.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// heaterSwitch.reactive.isOn <~> viewModel.isHeaterTurnedOn
	/// viewModel.isHeaterTurnedOn <~> heaterSwitch.reactive.isOn
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - property: The property to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the value binding.
	@discardableResult
	public static func <~> <P: ComposableMutablePropertyProtocol>(bindable: ValueBindable, property: P) -> Disposable? where P.Value == Value {
		return bindable.bind(to: property)
	}
}


// MARK: Action bindings

extension Action {
	/// Create an action binding between `bindable` and `action`.
	///
	/// The availability of the `bindable` is bound to the availability of `action`, and
	/// any value initiated by the `bindable` would be turned into an execution attempt of
	/// `action`. Errors of the `Action` are ignored by the binding.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// confirmButton.reactive.pressed <~> viewModel.submit
	/// viewModel.submit <~> confirmButton.reactive.pressed
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - action: The `Action` to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the action binding.
	@discardableResult
	public static func <~><Bindable>(action: Action, bindable: Bindable) -> Disposable? where Bindable: ActionBindableProtocol, Bindable.Value == Input {
		return bindable <~> action
	}
}

extension Action where Input == () {
	/// Create an action binding between `bindable` and `action`.
	///
	/// The availability of the `bindable` is bound to the availability of `action`, and
	/// any value initiated by the `bindable` would be turned into an execution attempt of
	/// `action`. Errors of the `Action` are ignored by the binding.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// confirmButton.reactive.pressed <~> viewModel.submit
	/// viewModel.submit <~> confirmButton.reactive.pressed
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - action: The `Action` to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the action binding.
	@discardableResult
	public static func <~> <Bindable>(action: Action, bindable: Bindable) -> Disposable? where Bindable: ActionBindableProtocol {
		return bindable <~> action
	}

	/// Create an action binding between `bindable` and `action`.
	///
	/// The availability of the `bindable` is bound to the availability of `action`, and
	/// any value initiated by the `bindable` would be turned into an execution attempt of
	/// `action`. Errors of the `Action` are ignored by the binding.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// confirmButton.reactive.pressed <~> viewModel.submit
	/// viewModel.submit <~> confirmButton.reactive.pressed
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - action: The `Action` to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the action binding.
	@discardableResult
	public static func <~> <Bindable>(action: Action, bindable: Bindable) -> Disposable? where Bindable: ActionBindableProtocol, Bindable.Value == () {
		return bindable <~> action
	}
}

extension ActionBindableProtocol {
	/// Create an action binding between `bindable` and `action`.
	///
	/// The availability of the `bindable` is bound to the availability of `action`, and
	/// any value initiated by the `bindable` would be turned into an execution attempt of
	/// `action`. Errors of the `Action` are ignored by the binding.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// confirmButton.reactive.pressed <~> viewModel.submit
	/// viewModel.submit <~> confirmButton.reactive.pressed
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - action: The `Action` to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the action binding.
	@discardableResult
	public static func <~> <Output, Error>(bindable: Self, action: Action<Value, Output, Error>) -> Disposable? {
		return bindable.bind(to: action)
	}

	/// Create an action binding between `bindable` and `action`.
	///
	/// The availability of the `bindable` is bound to the availability of `action`, and
	/// any value initiated by the `bindable` would be turned into an execution attempt of
	/// `action`. Errors of the `Action` are ignored by the binding.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// confirmButton.reactive.pressed <~> viewModel.submit
	/// viewModel.submit <~> confirmButton.reactive.pressed
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - action: The `Action` to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the action binding.
	@discardableResult
	public static func <~> <Output, Error>(bindable: Self, action: Action<(), Output, Error>) -> Disposable? {
		return bindable.mapOutput { _ in } <~> action
	}
}

extension ActionBindableProtocol where Value == () {
	/// Create an action binding between `bindable` and `action`.
	///
	/// The availability of the `bindable` is bound to the availability of `action`, and
	/// any value initiated by the `bindable` would be turned into an execution attempt of
	/// `action`. Errors of the `Action` are ignored by the binding.
	///
	/// ## Example
	/// ```
	/// // Both are equivalent.
	/// confirmButton.reactive.pressed <~> viewModel.submit
	/// viewModel.submit <~> confirmButton.reactive.pressed
	/// ```
	///
	/// - parameters:
	///   - bindable: The value bindable to bind with.
	///   - action: The `Action` to bind with.
	///
	/// - returns: A `Disposable` that can be used to tear down the action binding.
	@discardableResult
	public static func <~> <Output, Error>(bindable: Self, action: Action<(), Output, Error>) -> Disposable? {
		return bindable.bind(to: action)
	}
}
