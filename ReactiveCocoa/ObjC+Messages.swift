@objc internal protocol ObjCClassReporting {
	@objc(class)
	var objcClass: AnyClass! { get }
}

@objc internal protocol ObjCInvocation {
	var target: NSObject? { get set }
	var selector: Selector? { get set }

	@objc(methodSignature)
	var objcMethodSignature: AnyObject { get }

	@objc(getArgument:atIndex:)
	func copy(to buffer: UnsafeMutableRawPointer?, forArgumentAt index: Int)

	func invoke()
}

@objc internal protocol ObjCMethodSignature {
	var numberOfArguments: UInt { get }

	@objc(getArgumentTypeAtIndex:)
	func argumentType(at index: UInt) -> UnsafePointer<CChar>
}
