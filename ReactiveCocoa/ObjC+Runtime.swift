/// Search in `class` for any method that matches the supplied selector without
/// propagating to the ancestors.
///
/// - parameters:
///   - class: The class to search the method in.
///   - selector: The selector of the method.
///
/// - returns: The matching method, or `nil` if none is found.
internal func class_getImmediateMethod(_ `class`: AnyClass, _ selector: Selector) -> Method? {
	if let buffer = class_copyMethodList(`class`, nil) {
		defer { free(buffer) }

		var iterator = buffer
		while let method = iterator.pointee {
			if method_getName(method) == selector {
				return method
			}
			iterator = iterator.advanced(by: 1)
		}
	}

	return nil
}

/// Assert that the method does not contain types that cannot be intercepted.
///
/// - parameters:
///   - types: The type encoding C string of the method.
///
/// - returns: `true`.
internal func assertSupportedSignature(_ types: UnsafePointer<CChar>) {
	// Some types, including vector types, are not encoded. In these cases the
	// signature starts with the size of the argument frame.
	precondition(types.pointee < Int8(UInt8(ascii: "1")) || types.pointee > Int8(UInt8(ascii: "9")),
	             "unknown method return type not supported in type encoding: \(String(cString: types))")
	precondition(types.pointee != Int8(UInt8(ascii: "(")), "union method return type not supported")
	precondition(types.pointee != Int8(UInt8(ascii: "{")), "struct method return type not supported")
	precondition(types.pointee != Int8(UInt8(ascii: "[")), "array method return type not supported")
	precondition(types.pointee != Int8(UInt8(ascii: "j")), "complex method return type not supported")
}

internal func isNonVoidReturning(_ types: UnsafePointer<CChar>) -> Bool {
	return types.pointee == Int8(UInt8(ascii: "v"))
}
