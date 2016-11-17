import ReactiveSwift

private let swizzledExternalClasses = Atomic<Set<ObjCClass>>([])

private func subclassName(of class: ObjCClass) -> String {
	return `class`.name.appending("_RACSwift")
}

internal func swizzleClass(_ instance: NSObject) -> ObjCClass {
	let key = (#function as StaticString).utf8Start

	if let knownSubclass = instance.value(forAssociatedKey: key) as! ObjCClass? {
		return knownSubclass
	}

	let perceivedClass = ObjCClass(instance.objcClass)
	let realClass = ObjCClass.type(of: instance)

	if perceivedClass != realClass {
		// If the class is already lying about what it is, it's probably a KVO
		// dynamic subclass or something else that we shouldn't subclass
		// ourselves.
		//
		// Use this runtime subclass directly.
		swizzledExternalClasses.modify { classes in
			if !classes.contains(realClass) {
				classes.insert(realClass)
				replaceGetClass(in: realClass, decoy: perceivedClass)
			}
		}

		return realClass
	} else {
		let name = subclassName(of: perceivedClass)
		let subclass: ObjCClass

		if let existingClass = ObjCClass(name: name) {
			subclass = existingClass
		} else {
			subclass = ObjCClass.allocate(name: name, superclass: perceivedClass) { subclass in
				replaceGetClass(in: subclass, decoy: perceivedClass)
			}
		}

		instance.setClass(subclass)
		instance.setValue(subclass, forAssociatedKey: key)
		return subclass
	}
}

private func replaceGetClass(in class: ObjCClass, decoy perceivedClass: ObjCClass) {
	let getClass: @convention(block) (Any) -> AnyClass = { _ in
		return perceivedClass.reference
	}

	// Swizzle `-class`.
	_ = `class`.replaceMethod(with: CFunction(block: getClass),
														for: ObjCSelector.getClass,
														types: ObjCMethodEncoding.getClass)

	// Swizzle `+class`.
	_ = `class`.metaclass.replaceMethod(with: CFunction(block: getClass),
																			for: ObjCSelector.getClass,
																			types: ObjCMethodEncoding.getClass)
}
