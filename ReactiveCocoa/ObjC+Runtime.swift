internal struct ObjCClass {
	let reference: AnyClass

	var name: String {
		return String(cString: class_getName(reference))
	}

	var metaclass: ObjCClass {
		return ObjCClass(object_getClass(reference)!)
	}

	var superclass: ObjCClass? {
		if let superclass = class_getSuperclass(reference) {
			return ObjCClass(superclass)
		}

		return nil
	}

	init(_ reference: AnyClass) {
		self.reference = reference
	}

	init?(name: String) {
		if let classRef = name.withCString(objc_getClass) {
			self.reference = classRef as! AnyClass
		} else {
			return nil
		}
	}

	func addMethod(with implementation: CFunction, for selector: Selector, types: UnsafePointer<Int8>) {
		class_addMethod(reference, selector, implementation.reference, types)
	}

	func replaceMethod(with implementation: CFunction, for selector: Selector, types: UnsafePointer<Int8>) -> CFunction? {
		let imp = class_replaceMethod(reference, selector, implementation.reference, types)
		return imp.map(CFunction.init)
	}

	func method(for selector: Selector, searchesAncestors: Bool = true) -> ObjCMethod? {
		if searchesAncestors {
			if let method = class_getInstanceMethod(reference, selector) {
				return ObjCMethod(method, in: self)
			}
		} else {
			var count: UInt32 = 0
			let buffer = class_copyMethodList(reference, &count)
			let methods = UnsafeBufferPointer(start: buffer, count: Int(count))

			defer { free(buffer) }

			for method in methods {
				if method_getName(method!) == selector {
					return ObjCMethod(method!, in: self)
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
	static func type(of object: NSObject) -> ObjCClass {
		return ObjCClass(object_getClass(object))
	}

	static func allocate(name: String, superclass: ObjCClass, setup: (ObjCClass) throws -> Void) rethrows -> ObjCClass {
		let subclass = name.withCString { name in
			return ObjCClass(objc_allocateClassPair(superclass.reference, name, 0)!)
		}

		try setup(subclass)
		objc_registerClassPair(subclass.reference)

		return subclass
	}
}

internal struct ObjCMethod {
	fileprivate let parent: ObjCClass
	fileprivate let reference: Method

	var function: CFunction {
		return CFunction(method_getImplementation(reference))
	}

	var typeEncoding: UnsafePointer<CChar> {
		return method_getTypeEncoding(reference)
	}

	init(_ reference: Method, in class: ObjCClass) {
		self.reference = reference
		self.parent = `class`
	}

	func replaceImplementation(_ implementation: CFunction) -> CFunction? {
		return parent.replaceMethod(with: function,
		                            for: method_getName(reference),
		                            types: method_getTypeEncoding(reference))
	}
}

internal struct CFunction {
	static let forwarding = CFunction(_rac_objc_msgForward())

	fileprivate let reference: IMP

	init<U>(assuming block: U) {
		self.reference = unsafeBitCast(block, to: IMP.self)
	}

	fileprivate init(_ reference: IMP) {
		self.reference = reference
	}

	init(block: Any) {
		self.reference = imp_implementationWithBlock(block)
	}
}
