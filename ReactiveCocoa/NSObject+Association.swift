import ReactiveSwift

internal struct AssociationKey<Value> {
	fileprivate let address: UnsafeRawPointer
	fileprivate let `default`: Value!

	/// Create an ObjC association key.
	///
	/// - warning: The key must be uniqued.
	///
	/// - parameters:
	///   - default: The default value, or `nil` to trap on undefined value. It is
	///              ignored if `Value` is an optional.
	init(default: Value? = nil) {
		self.address = UnsafeRawPointer(UnsafeMutablePointer<UInt8>.allocate(capacity: 1))
		self.default = `default`
	}

	/// Create an ObjC association key from a `StaticString`.
	///
	/// - precondition: `key` has a pointer representation.
	///
	/// - parameters:
	///   - default: The default value, or `nil` to trap on undefined value. It is
	///              ignored if `Value` is an optional.
	init(_ key: StaticString, default: Value? = nil) {
		assert(key.hasPointerRepresentation)
		self.address = UnsafeRawPointer(key.utf8Start)
		self.default = `default`
	}

	/// Create an ObjC association key from a `Selector`.
	///
	/// - parameters:
	///   - default: The default value, or `nil` to trap on undefined value. It is
	///              ignored if `Value` is an optional.
	init(_ key: Selector, default: Value? = nil) {
		self.address = UnsafeRawPointer(key.utf8Start)
		self.default = `default`
	}
}

internal struct Associations<Base: AnyObject> {
	fileprivate let base: Base

	init(_ base: Base) {
		self.base = base
	}
}

extension Reactive where Base: NSObjectProtocol {
	/// Retrieve the associated value for the specified key. If the value does not
	/// exist, `initial` would be called and the returned value would be
	/// associated subsequently.
	///
	/// - parameters:
	///   - key: An optional key to differentiate different values.
	///   - initial: The action that supples an initial value.
	///
	/// - returns: The associated value for the specified key.
	internal func associatedValue<T>(forKey key: StaticString = #function, initial: (Base) -> T) -> T {
		let key = AssociationKey<T?>(key)

		if let value = base.associations.value(forKey: key) {
			return value
		}

		let value = initial(base)
		base.associations.setValue(value, forKey: key)

		return value
	}
}

extension NSObjectProtocol {
	@nonobjc internal var associations: Associations<Self> {
		return Associations(self)
	}
}

extension Associations {
	/// Retrieve the associated value for the specified key.
	///
	/// - parameters:
	///   - key: The key.
	///
	/// - returns: The associated value, or the default value if no value has been
	///            associated with the key.
	internal func value<Value>(forKey key: AssociationKey<Value>) -> Value {
		return (objc_getAssociatedObject(base, key.address) as! Value?) ?? key.default
	}

	/// Retrieve the associated value for the specified key.
	///
	/// - parameters:
	///   - key: The key.
	///
	/// - returns: The associated value, or `nil` if no value is associated with
	///            the key.
	internal func value<Value>(forKey key: AssociationKey<Value?>) -> Value? {
		return objc_getAssociatedObject(base, key.address) as! Value?
	}

	/// Set the associated value for the specified key.
	///
	/// - parameters:
	///   - value: The value to be associated.
	///   - key: The key.
	internal func setValue<Value>(_ value: Value, forKey key: AssociationKey<Value>) {
		objc_setAssociatedObject(base, key.address, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}

	/// Set the associated value for the specified key.
	///
	/// - parameters:
	///   - value: The value to be associated.
	///   - key: The key.
	internal func setValue<Value>(_ value: Value?, forKey key: AssociationKey<Value?>) {
		objc_setAssociatedObject(base, key.address, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}
}

/// Set the associated value for the specified key.
///
/// - parameters:
///   - value: The value to be associated.
///   - key: The key.
///   - address: The address of the object.
internal func unsafeSetAssociatedValue<Value>(_ value: Value?, forKey key: AssociationKey<Value>, forObjectAt address: UnsafeRawPointer) {
	_rac_objc_setAssociatedObject(address, key.address, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}
