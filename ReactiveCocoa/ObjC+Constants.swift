import Foundation

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

	private static func extract(_ string: StaticString) -> UnsafePointer<CChar> {
		return UnsafeRawPointer(string.utf8Start).assumingMemoryBound(to: CChar.self)
	}
}

/// Objective-C type encoding.
///
/// The enum does not cover all options, but only those that are expressive in
/// Swift.
internal enum ObjCTypeEncoding: Int8 {
	case char = 99
	case int = 105
	case short = 115
	case long = 108
	case longLong = 113

	case unsignedChar = 67
	case unsignedInt = 73
	case unsignedShort = 83
	case unsignedLong = 76
	case unsignedLongLong = 81

	case float = 102
	case double = 100

	case bool = 66

	case object = 64
	case type = 35
	case selector = 58

	case undefined = -1
}
