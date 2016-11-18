extension NSObject {
	/// The class of the instance reported by the ObjC `-class:` message.
	///
	/// - note: `type(of:)` might return the runtime subclass, while this property
	///         always returns the original class.
	@nonobjc internal var objcClass: AnyClass {
		return (self as AnyObject).objcClass
	}

	/// Set the class of `self`.
	///
	/// - parameters:
	///   - class: The new class of `self`.
	@nonobjc internal func setClass(_ class: ObjCClass) {
		object_setClass(self, `class`.reference)
	}
}
