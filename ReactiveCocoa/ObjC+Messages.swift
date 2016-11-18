// Unavailable classes like `NSInvocation` can still be passed into Swift as
// `AnyObject`, and receive messages via `AnyObject`'s message dispatching.
//
// These `@objc` protocols host the method signatures so that they can be used
// with `AnyObject`.

// `-class` and `+class`.
@objc internal protocol ObjCClassReporting {
	@objc(class)
	var objcClass: AnyClass! { get }
}

// Methods of `NSInvocation`.
@objc internal protocol ObjCInvocation {
	@objc(setSelector:)
	func setSelector(_ selector: Selector)

	@objc(methodSignature)
	var objcMethodSignature: AnyObject { get }

	@objc(getArgument:atIndex:)
	func copy(to buffer: UnsafeMutableRawPointer?, forArgumentAt index: Int)

	func invoke()
}

// Methods of `NSMethodSignature`.
@objc internal protocol ObjCMethodSignature {
	var numberOfArguments: UInt { get }

	@objc(getArgumentTypeAtIndex:)
	func argumentType(at index: UInt) -> UnsafePointer<CChar>

	@objc(signatureWithObjCTypes:)
	static func signature(withObjCTypes typeEncoding: UnsafePointer<Int8>) -> AnyObject
}
