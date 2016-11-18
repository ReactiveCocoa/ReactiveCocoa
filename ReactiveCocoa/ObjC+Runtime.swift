func class_getImmediateMethod(_ `class`: AnyClass, _ selector: Selector) -> Method? {
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
