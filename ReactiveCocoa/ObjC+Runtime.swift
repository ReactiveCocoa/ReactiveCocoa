/// Search in `class` for any method that matches the supplied selector without
/// propagating to the ancestors.
///
/// - parameters:
///   - class: The class to search the method in.
///   - selector: The selector of the method.
///
/// - returns:
///   The matching method, or `nil` if none is found.
internal func class_getImmediateMethod(_ `class`: AnyClass, _ selector: Selector) -> Method? {
	var count: UInt32 = 0
	let buffer = class_copyMethodList(`class`, &count)
	let methods = UnsafeBufferPointer(start: buffer, count: Int(count))

	defer { free(buffer) }

	for method in methods {
		if method_getName(method!) == selector {
			return method!
		}
	}

	return nil
}
