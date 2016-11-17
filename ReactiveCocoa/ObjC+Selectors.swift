internal enum ObjCSelector {
	static let forwardInvocation = Selector((("forwardInvocation:")))
	static let methodSignatureForSelector = Selector((("methodSignatureForSelector:")))
	static let getClass = Selector((("class")))
}

internal enum ObjCMethodEncoding {
	static let forwardInvocation = extract("v@:@")
	static let methodSignatureForSelector = extract("v@::")
	static let getClass = extract("#@:")

	private static func extract(_ string: StaticString) -> UnsafePointer<CChar> {
		return UnsafeRawPointer(string.utf8Start).assumingMemoryBound(to: CChar.self)
	}
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
