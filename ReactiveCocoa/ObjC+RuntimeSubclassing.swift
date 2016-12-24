import ReactiveSwift

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

	if let knownSubclass = instance.associatedValue(forKey: key) as! AnyClass? {
		return knownSubclass
	}

	let perceivedClass: AnyClass = instance.objcClass
	let realClass: AnyClass = object_getClass(instance)!

	if perceivedClass != realClass {
		// If the class is already lying about what it is, it's probably a KVO
		// dynamic subclass or something else that we shouldn't subclass at runtime.
		synchronized(realClass) {
			let isSwizzled = objc_getAssociatedObject(realClass, AssociationKey.runtimeSubclassed) as! Bool? ?? false
			if !isSwizzled {
				replaceGetClass(in: realClass, decoy: perceivedClass)
				objc_setAssociatedObject(realClass, AssociationKey.runtimeSubclassed, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
		instance.setAssociatedValue(subclass, forKey: key)
		return subclass
	}
}

private func subclassName(of class: AnyClass) -> String {
	return String(cString: class_getName(`class`)).appending("_RACSwift")
}

/// Swizzle the `-class` and `+class` methods.
///
/// - parameters:
///   - class: The class to swizzle.
///   - perceivedClass: The class to be reported by the methods.
private func replaceGetClass(in class: AnyClass, decoy perceivedClass: AnyClass) {
	let getClass: @convention(block) (Any) -> AnyClass = { _ in
		return perceivedClass
	}

	let impl = imp_implementationWithBlock(getClass as Any)

	_ = class_replaceMethod(`class`,
	                        ObjCSelector.getClass,
	                        impl,
	                        ObjCMethodEncoding.getClass)

	_ = class_replaceMethod(object_getClass(`class`),
	                        ObjCSelector.getClass,
	                        impl,
	                        ObjCMethodEncoding.getClass)
}
