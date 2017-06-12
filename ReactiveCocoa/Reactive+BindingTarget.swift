import ReactiveSwift

#if swift(>=3.2)
extension ReactiveExtensionsProvider where Self: AnyObject {
	/// Create a binding target that updates the given key path with values received
	/// from a unidirectional binding constructed by the `<~` operator.
	///
	/// `reactive(_:)` by default uses a `UIScheduler`. Provide your own `Scheduler`
	/// instances if you wish the values to be consumed in other schedulers.
	///
	/// ## Example
	/// ```
	/// textField.reactive(\.text) <~ viewModel.title
	/// ```
	///
	/// - parameters:
	///   - keyPath: The key path to update.
	///   - scheduler: The scheduler to update the key path on. By default, a
	///                `UIScheduler` would be used.
	///
	/// - returns: A binding target that can be used with the `<~` operator.
	public func reactive<Value>(
		_ keyPath: ReferenceWritableKeyPath<Self, Value>,
		on scheduler: Scheduler = UIScheduler()
	) -> BindingTarget<Value> {
		return BindingTarget(on: scheduler, object: self, keyPath: keyPath)
	}

	public func reactive(
		_ method: @escaping (Self) -> () -> Void,
		on scheduler: Scheduler = UIScheduler()
	) -> BindingTarget<()> {
		return BindingTarget(on: scheduler, object: self, method: method)
	}

	public func reactive<Value>(
		_ method: @escaping (Self) -> (Value) -> Void,
		on scheduler: Scheduler = UIScheduler()
	) -> BindingTarget<Value> {
		return BindingTarget(on: scheduler, object: self, method: method)
	}

	public func reactive<U, V>(
		_ method: @escaping (Self) -> (U, V) -> Void,
		on scheduler: Scheduler = UIScheduler()
	) -> BindingTarget<(U, V)> {
		return BindingTarget(on: scheduler, object: self, method: method)
	}

	public func reactive<Value, U>(
		_ method: @escaping (Self) -> (Value, U) -> Void,
		second: U,
		on scheduler: Scheduler = UIScheduler()
	) -> BindingTarget<Value> {
		return BindingTarget(on: scheduler, object: self, method: method, second: second)
	}
}

extension BindingTarget {
	public init<Object: AnyObject>(on scheduler: Scheduler = ImmediateScheduler(), object: Object, keyPath: ReferenceWritableKeyPath<Object, Value>) {
		self.init(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: object), object: object, keyPath: keyPath)
	}
}
#endif

extension BindingTarget where Value == () {
	public init<Object: AnyObject>(on scheduler: Scheduler = ImmediateScheduler(), object: Object, method: @escaping (Object) -> () -> Void) {
		self.init(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: object)) { [weak object] _ in
			if let object = object {
				method(object)()
			}
		}
	}
}

extension BindingTarget {
	public init<Object: AnyObject>(on scheduler: Scheduler = ImmediateScheduler(), object: Object, method: @escaping (Object) -> (Value) -> Void) {
		self.init(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: object)) { [weak object] value in
			if let object = object {
				method(object)(value)
			}
		}
	}

	public init<Object: AnyObject, U, V>(on scheduler: Scheduler = ImmediateScheduler(), object: Object, method: @escaping (Object) -> (U, V) -> Void) where Value == (U, V) {
		self.init(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: object)) { [weak object] value in
			if let object = object {
				method(object)(value.0, value.1)
			}
		}
	}

	public init<Object: AnyObject, U>(on scheduler: Scheduler = ImmediateScheduler(), object: Object, method: @escaping (Object) -> (Value, U) -> Void, second: U) {
		self.init(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: object)) { [weak object] value in
			if let object = object {
				method(object)(value, second)
			}
		}
	}
}
