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
		var value = objc_getAssociatedObject(base, key.utf8Start) as! T?
		if value == nil {
			value = initial(base)
			objc_setAssociatedObject(base, key.utf8Start, value, .OBJC_ASSOCIATION_RETAIN)
		}
		return value!
	}
}
