import Foundation

/// Search in `class` for any method that matches the supplied selector without
/// propagating to the ancestors.
///
/// - parameters:
///   - class: The class to search the method in.
///   - selector: The selector of the method.
///
/// - returns: The matching method, or `nil` if none is found.
internal func class_getImmediateMethod(_ `class`: AnyClass, _ selector: Selector) -> Method? {
	var total: UInt32 = 0

	if let methods = class_copyMethodList(`class`, &total) {
		defer { free(methods) }

		for index in 0 ..< Int(total) {
			let method = methods[index]

			if method_getName(method) == selector {
				return method
			}
		}
	}

	return nil
}
