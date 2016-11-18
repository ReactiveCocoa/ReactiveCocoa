/// Represents a class in the Objective-C runtime.
internal struct ObjCClass {
	enum Error: Swift.Error {
		/// The selector has already been implemented in the class.
		case methodAlreadyExist
	}

	/// The corresponding class object.
	let reference: AnyClass

	/// The name of the class.
	var name: String {
		return String(cString: class_getName(reference))
	}

	/// The meta class of the class.
	var metaclass: ObjCClass {
		return ObjCClass(object_getClass(reference)!)
	}

	/// The superclass of the class.
	var superclass: ObjCClass? {
		if let superclass = class_getSuperclass(reference) {
			return ObjCClass(superclass)
		}

		return nil
	}

	/// Initialize from a class object.
	///
	/// - parameters:
	///   - reference: The class object.
	init(_ reference: AnyClass) {
		self.reference = reference
	}

	/// Initialize from a class name.
	///
	/// - parameters:
	///   - name: The class name.
	///
	/// - returns:
	///   The found class, or `nil` if it does not match any.
	init?(name: String) {
		if let classRef = name.withCString(objc_getClass) {
			self.reference = classRef as! AnyClass
		} else {
			return nil
		}
	}

	/// Add a method to the class.
	///
	/// - parameters:
	///   - implementation: The implementation of the method.
	///   - selector: The selector of the method.
	///   - types: The type encoding string of the method.
	///
	/// - throws: `Error.methodAlreadyExists` if the selector has already been
	///            implemented.
	func addMethod(with implementation: CFunction, for selector: Selector, types: UnsafePointer<Int8>) throws {
		if !class_addMethod(reference, selector, implementation.reference, types) {
			throw Error.methodAlreadyExist
		}
	}

	/// Replace a method of the class.
	///
	/// - parameters:
	///   - implementation: The implementation of the method, or `nil` to remove
	///                     any implementation from the method.
	///   - selector: The selector of the method.
	///   - types: The type encoding string of the method.
	///
	/// - returns:
	///   The implementation being swapped out, or `nil` if the selector has not
	///   ever been implemented before.
	func replaceMethod(with implementation: CFunction?, for selector: Selector, types: UnsafePointer<Int8>) -> CFunction? {
		let imp = class_replaceMethod(reference, selector, implementation?.reference, types)
		return imp.map(CFunction.init)
	}

	/// Search for a method that matches the supplied selector.
	/// 
	/// - parameters:
	///   - selector: The selector of the method.
	///   - searchesAncestors: Indicates whether the search propagates to the
	///                        superclass, or should be limited to the class
	///                        itself.
	///
	/// - returns:
	///   The matching method, or `nil` if none is found.
	func method(for selector: Selector, searchesAncestors: Bool = true) -> ObjCMethod? {
		if searchesAncestors {
			if let method = class_getInstanceMethod(reference, selector) {
				return ObjCMethod(method)
			}
		} else {
			var count: UInt32 = 0
			let buffer = class_copyMethodList(reference, &count)
			let methods = UnsafeBufferPointer(start: buffer, count: Int(count))

			defer { free(buffer) }

			for method in methods {
				if method_getName(method!) == selector {
					return ObjCMethod(method!)
				}
			}
		}

		return nil
	}
}

extension ObjCClass: Hashable {
	static func ==(left: ObjCClass, right: ObjCClass) -> Bool {
		return left.reference === right.reference
	}

	var hashValue: Int {
		return ObjectIdentifier(reference).hashValue
	}
}

extension ObjCClass {
	/// Get the class of `object`.
	///
	/// - note: This method makes queries through the Objective-C runtime, and may
	///         have different results from `[NSObject class]` in isa-swizzled
	///         instances.
	///
	/// - parameters:
	///   - object: The object to query.
	///
	/// - returns:
	///   The runtime class of `object`.
	static func type(of object: NSObject) -> ObjCClass {
		return ObjCClass(object_getClass(object))
	}

	/// Create a runtime subclass.
	///
	/// - parameters:
	///   - name: The name of the subclass.
	///   - superclass: The superclass of the subclass.
	///   - setup: The action to be called before the subclass is registered to
	///            the Objective-C runtime.
	///
	/// - returns:
	///   The created subclass.
	static func allocate(name: String, superclass: ObjCClass, setup: (ObjCClass) throws -> Void) rethrows -> ObjCClass {
		let subclass = name.withCString { name in
			return ObjCClass(objc_allocateClassPair(superclass.reference, name, 0)!)
		}

		try setup(subclass)
		objc_registerClassPair(subclass.reference)

		return subclass
	}
}

/// Represents a method of a class in the Objective-C runtime.
internal struct ObjCMethod {
	fileprivate let reference: Method

	/// The implementation of the method.
	var function: CFunction {
		return CFunction(method_getImplementation(reference))
	}

	/// The method type encoding string of the method.
	var typeEncoding: UnsafePointer<CChar> {
		return method_getTypeEncoding(reference)
	}

	fileprivate init(_ reference: Method) {
		self.reference = reference
	}
}

/// Represents a function pointer that can be used as method implementations.
internal struct CFunction {
	/// The Objective-C message forwarder.
	static let forwarding = CFunction(_rac_objc_msgForward)

	fileprivate let reference: IMP

	/// Indicates if `self` is the Objective-C message forwarder.
	var isForwarder: Bool {
		return reference == CFunction.forwarding.reference
	}

	/// Create a pointer by casting `block` as a C function pointer.
	///
	/// - warning: `block` must be a `@convention(c)` closure.
	init<U>(assuming block: U) {
		self.reference = unsafeBitCast(block, to: IMP.self)
	}

	/// Create a pointer by casting `block` as a C function pointer.
	///
	/// - warning: `block` must have its first argument being `Any` for the
	///            receiver.
	init(block: Any) {
		self.reference = imp_implementationWithBlock(block)
	}

	fileprivate init(_ reference: IMP) {
		self.reference = reference
	}
}

extension CFunction: Equatable {
	static func ==(left: CFunction, right: CFunction) -> Bool {
		return left.reference == right.reference
	}
}
