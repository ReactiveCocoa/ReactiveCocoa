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
