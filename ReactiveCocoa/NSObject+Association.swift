import ReactiveSwift

extension Reactive where Base: NSObject {
	/// Retrieve the associated value for the specified key. If the value does not
	/// exist, `initial` would be called and the returned value would be
	/// associated subsequently.
	///
	/// - parameters:
	///   - key: An optional key to differentiate different values.
	///   - initial: The action that supples an initial value.
	///
	/// - returns:
	///   The associated value for the specified key.
	internal func associatedValue<T>(forKey key: StaticString = #function, initial: (Base) -> T) -> T {
		var value = base.value(forAssociatedKey: key.utf8Start) as! T?
		if value == nil {
			value = initial(base)
			base.setValue(value, forAssociatedKey: key.utf8Start)
		}
		return value!
	}
}

extension NSObject {
	/// Retrieve the associated value for the specified key.
	///
	/// - parameters:
	///   - key: The key.
	///
	/// - returns:
	///   The associated value, or `nil` if no value is associated with the key.
	internal func value(forAssociatedKey key: UnsafeRawPointer) -> Any? {
		return objc_getAssociatedObject(self, key)
	}

	/// Set the associated value for the specified key.
	///
	/// - parameters:
	///   - value: The value to be associated.
	///   - key: The key.
	///   - weak: `true` if the value should be weakly referenced. `false`
	///           otherwise.
	internal func setValue(_ value: Any?, forAssociatedKey key: UnsafeRawPointer, weak: Bool = false) {
		objc_setAssociatedObject(self, key, value, weak ? .OBJC_ASSOCIATION_ASSIGN : .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
}
