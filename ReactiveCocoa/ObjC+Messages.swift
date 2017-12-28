// Unavailable classes like `NSInvocation` can still be passed into Swift as
// `AnyClass` and `AnyObject`, and receive messages as `AnyClass` and
// `AnyObject` existentials.
//
// These `@objc` protocols host the method signatures so that they can be used
// with `AnyObject`.

internal let NSInvocation: AnyClass = NSClassFromString("NSInvocation")!
internal let NSMethodSignature: AnyClass = NSClassFromString("NSMethodSignature")!

// Signatures defined in `@objc` protocols would be available for ObjC message
// sending via `AnyObject`.
@objc internal protocol ObjCClassReporting {
// An alias for `-class`, which is unavailable in Swift.
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

    @objc(getReturnValue:)
    func copyReturnValue(to buffer: UnsafeMutableRawPointer?)

	func invoke()

	@objc(invocationWithMethodSignature:)
	static func invocation(withMethodSignature signature: AnyObject) -> AnyObject
}

// Methods of `NSMethodSignature`.
@objc internal protocol ObjCMethodSignature {
	var numberOfArguments: UInt { get }

	@objc(getArgumentTypeAtIndex:)
	func argumentType(at index: UInt) -> UnsafePointer<CChar>

    var methodReturnType: UnsafePointer<CChar> { get }

    var methodReturnLength: UInt { get }

	@objc(signatureWithObjCTypes:)
	static func signature(withObjCTypes typeEncoding: UnsafePointer<Int8>) -> AnyObject
}
