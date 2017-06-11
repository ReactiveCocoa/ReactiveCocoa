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
}

extension BindingTarget {
	public init<Object: AnyObject>(object: Object, keyPath: ReferenceWritableKeyPath<Object, Value>) {
		self.init(lifetime: ReactiveCocoa.lifetime(of: object), object: object, keyPath: keyPath)
	}

	public init<Object: AnyObject>(on scheduler: Scheduler, object: Object, keyPath: ReferenceWritableKeyPath<Object, Value>) {
		self.init(on: scheduler, lifetime: ReactiveCocoa.lifetime(of: object), object: object, keyPath: keyPath)
	}
}
#endif
