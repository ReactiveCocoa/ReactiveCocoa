import ReactiveSwift

internal struct AssociationKey {
	private static let contiguous = UnsafeMutablePointer<UInt8>.allocate(capacity: 6)

	static let intercepted = contiguous
	static let signatureCache = contiguous + 1
	static let selectorCache = contiguous + 2
	static let runtimeSubclassed = contiguous + 3
	static let lifetime = contiguous + 4
	static let lifetimeToken = contiguous + 5
}

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
		var value = base.value(forAssociationKey: key.utf8Start) as! T?
		if value == nil {
			value = initial(base)
			base.setValue(value, forAssociationKey: key.utf8Start)
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
	@nonobjc internal func value(forAssociationKey key: UnsafeRawPointer) -> Any? {
		return objc_getAssociatedObject(self, key)
	}

	/// Set the associated value for the specified key.
	///
	/// - parameters:
	///   - value: The value to be associated.
	///   - key: The key.
	///   - weak: `true` if the value should be weakly referenced. `false`
	///           otherwise.
	@nonobjc internal func setValue(_ value: Any?, forAssociationKey key: UnsafeRawPointer, weak: Bool = false) {
		objc_setAssociatedObject(self, key, value, weak ? .OBJC_ASSOCIATION_ASSIGN : .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
}
