import ReactiveSwift

private var isSwizzledKey = 0
private var test = 0

/// ISA-swizzle the class of the supplied instance.
///
/// - note: If the instance has already been isa-swizzled, the swizzling happens
///         in place in the runtime subclass created by external parties.
///
/// - parameters:
///   - instance: The instance to be swizzled.
///
/// - returns:
///   The runtime subclass of the perceived class of the instance.
internal func swizzleClass(_ instance: NSObject) -> AnyClass {
	let key = (#function as StaticString).utf8Start

	if let knownSubclass = instance.value(forAssociatedKey: key) as! AnyClass? {
		return knownSubclass
	}

	let perceivedClass: AnyClass = instance.objcClass
	let realClass: AnyClass = object_getClass(instance)!

	if perceivedClass != realClass {
		// If the class is already lying about what it is, it's probably a KVO
		// dynamic subclass or something else that we shouldn't subclass at runtime.
		synchronized(realClass) {
			let isSwizzled = objc_getAssociatedObject(realClass, &isSwizzledKey) as! Bool? ?? false

			if !isSwizzled {
				replaceGetClass(in: realClass, decoy: perceivedClass)
				objc_setAssociatedObject(realClass, &isSwizzledKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

				let token = Lifetime.Token()
				objc_setAssociatedObject(realClass, &test, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

				Lifetime(token).ended.observeCompleted {

					let a = 1
					_ = a

				}
			}
		}

		return realClass
	} else {
		let name = subclassName(of: perceivedClass)
		let subclass: AnyClass = name.withCString { cString in
			if let existingClass = objc_getClass(cString) as! AnyClass? {
				return existingClass
			} else {
				let subclass: AnyClass = objc_allocateClassPair(perceivedClass, cString, 0)!
				replaceGetClass(in: subclass, decoy: perceivedClass)
				objc_registerClassPair(subclass)
				return subclass
			}
		}

		object_setClass(instance, subclass)
		instance.setValue(subclass, forAssociatedKey: key)
		return subclass
	}
}

private func subclassName(of class: AnyClass) -> String {
	return String(cString: class_getName(`class`)).appending("_RACSwift")
}

private func replaceGetClass(in class: AnyClass, decoy perceivedClass: AnyClass) {
	let getClass: @convention(block) (Any) -> AnyClass = { _ in
		return perceivedClass
	}

	let impl = imp_implementationWithBlock(getClass as Any)

	// Swizzle `-class`.
	_ = class_replaceMethod(`class`,
	                        ObjCSelector.getClass,
	                        impl,
	                        ObjCMethodEncoding.getClass)

	// Swizzle `+class`.
	_ = class_replaceMethod(object_getClass(`class`),
	                        ObjCSelector.getClass,
	                        impl,
	                        ObjCMethodEncoding.getClass)
}
