// Unavailable selectors in Swift.
internal enum ObjCSelector {
	static let forwardInvocation = Selector((("forwardInvocation:")))
	static let methodSignatureForSelector = Selector((("methodSignatureForSelector:")))
	static let getClass = Selector((("class")))
}

// Method encoding of the unavailable selectors.
internal enum ObjCMethodEncoding {
	static let forwardInvocation = extract("v@:@")
	static let methodSignatureForSelector = extract("v@::")
	static let getClass = extract("#@:")
	static let repsondsToSelector = extract("c@::")

	private static func extract(_ string: StaticString) -> UnsafePointer<CChar> {
		return UnsafeRawPointer(string.utf8Start).assumingMemoryBound(to: CChar.self)
	}
}
