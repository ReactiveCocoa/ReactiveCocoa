/// Whether the runtime subclass has already been prepared for message forwarding.
fileprivate let interceptedKey = AssociationKey(default: false)

/// Holds the method signature cache of the runtime subclass.
fileprivate let signatureCacheKey = AssociationKey<SignatureCache>()

/// Holds the method selector cache of the runtime subclass.
fileprivate let selectorCacheKey = AssociationKey<SelectorCache>()

extension NSObject {
	@discardableResult
	@nonobjc internal func enableMessageForwarding(_ action: (AnyClass, SelectorCache, SignatureCache) -> Void) -> AnyClass {
		let subclass: AnyClass = swizzleClass(self)
		let subclassAssociations = Associations(subclass as AnyObject)

		// FIXME: Compiler asks to handle a mysterious throw.
		return try! ReactiveCocoa.synchronized(subclass) {
			let isSwizzled = subclassAssociations.value(forKey: interceptedKey)

			let signatureCache: SignatureCache
			let selectorCache: SelectorCache

			if isSwizzled {
				signatureCache = subclassAssociations.value(forKey: signatureCacheKey)
				selectorCache = subclassAssociations.value(forKey: selectorCacheKey)
			} else {
				signatureCache = SignatureCache()
				selectorCache = SelectorCache()

				subclassAssociations.setValue(signatureCache, forKey: signatureCacheKey)
				subclassAssociations.setValue(selectorCache, forKey: selectorCacheKey)
				subclassAssociations.setValue(true, forKey: interceptedKey)

				implementForwardInvocation(subclass, selectorCache)
				setupMethodSignatureCaching(subclass, signatureCache)
			}

			action(subclass, selectorCache, signatureCache)
			return subclass
		}
	}
}

/// Swizzle `realClass` to enable message forwarding for method interception.
///
/// - parameters:
///   - realClass: The runtime subclass to be swizzled.
private func implementForwardInvocation(_ realClass: AnyClass, _ selectorCache: SelectorCache) {
	let perceivedClass: AnyClass = class_getSuperclass(realClass)

	typealias ForwardInvocationImpl = @convention(block) (Unmanaged<NSObject>, AnyObject) -> Void
	let newForwardInvocation: ForwardInvocationImpl = { [isDelegateProxy = isDelegateProxy(realClass)] objectRef, invocation in
		let selector = invocation.selector!
		let alias = selectorCache.alias(for: selector)
		let interopAlias = selectorCache.interopAlias(for: selector)

		defer { interceptingObject(objectRef, didInvokeSelectorOfAlias: alias, with: invocation) }

		if let method = class_getInstanceMethod(perceivedClass, selector) {
			let typeEncoding = method_getTypeEncoding(method)

			if class_respondsToSelector(realClass, interopAlias) {
				// RAC has preserved an immediate implementation found in the runtime
				// subclass that was supplied by an external party.
				//
				// As the KVO setter relies on the selector to work, it has to be invoked
				// by swapping in the preserved implementation and restore to the message
				// forwarder afterwards.
				//
				// However, the IMP cache would be thrashed due to the swapping.

				let topLevelClass: AnyClass = object_getClass(objectRef.takeUnretainedValue())

				// The locking below prevents RAC swizzling attempts from intervening the
				// invocation.
				//
				// Given the implementation of `swizzleClass`, `topLevelClass` can only be:
				// (1) the same as `realClass`; or (2) a subclass of `realClass`. In other
				// words, this would deadlock only if the locking order is not followed in
				// other nested locking scenarios of these metaclasses at compile time.

				synchronized(topLevelClass) {
					func swizzle() {
						let interopImpl = class_getMethodImplementation(topLevelClass, interopAlias)

						let previousImpl = class_replaceMethod(topLevelClass, selector, interopImpl, typeEncoding)
						invocation.invoke()

						_ = class_replaceMethod(topLevelClass, selector, previousImpl, typeEncoding)
					}

					if topLevelClass != realClass {
						synchronized(realClass) {
							// In addition to swapping in the implementation, the message
							// forwarding needs to be temporarily disabled to prevent circular
							// invocation.
							_ = class_replaceMethod(realClass, selector, nil, typeEncoding)
							swizzle()
							_ = class_replaceMethod(realClass, selector, _rac_objc_msgForward, typeEncoding)
						}
					} else {
						swizzle()
					}
				}

				return
			}

			if let impl = method_getImplementation(method), impl != _rac_objc_msgForward {
				// The perceived class, or its ancestors, responds to the selector.
				//
				// The implementation is invoked through the selector alias, which
				// reflects the latest implementation of the selector in the perceived
				// class.

				if class_getMethodImplementation(realClass, alias) != impl {
					// Update the alias if and only if the implementation has changed, so as
					// to avoid thrashing the IMP cache.
					_ = class_replaceMethod(realClass, alias, impl, typeEncoding)
				}

				invocation.setSelector(alias)
				invocation.invoke()

				return
			}
		}

		guard !isDelegateProxy else {
			return unsafeDelegateProxy(objectRef, didInvoke: selector, with: invocation)
		}

		// Forward the invocation to the closest `forwardInvocation(_:)` in the
		// inheritance hierarchy, or the default handler returned by the runtime
		// if it finds no implementation.
		typealias SuperForwardInvocation = @convention(c) (Unmanaged<NSObject>, Selector, AnyObject) -> Void
		let impl = class_getMethodImplementation(perceivedClass, ObjCSelector.forwardInvocation)
		let forwardInvocation = unsafeBitCast(impl, to: SuperForwardInvocation.self)
		forwardInvocation(objectRef, ObjCSelector.forwardInvocation, invocation)
	}

	_ = class_replaceMethod(realClass,
	                        ObjCSelector.forwardInvocation,
	                        imp_implementationWithBlock(newForwardInvocation as Any),
	                        ObjCMethodEncoding.forwardInvocation)
}

/// Swizzle `realClass` to accelerate the method signature retrieval, using a
/// signature cache that covers all known intercepted selectors of `realClass`.
///
/// - parameters:
///   - realClass: The runtime subclass to be swizzled.
///   - signatureCache: The method signature cache.
private func setupMethodSignatureCaching(_ realClass: AnyClass, _ signatureCache: SignatureCache) {
	let perceivedClass: AnyClass = class_getSuperclass(realClass)

	let newMethodSignatureForSelector: @convention(block) (Unmanaged<NSObject>, Selector) -> AnyObject? = { objectRef, selector in
		if let signature = signatureCache[selector] {
			return signature
		}

		typealias SuperMethodSignatureForSelector = @convention(c) (Unmanaged<NSObject>, Selector, Selector) -> AnyObject?
		let impl = class_getMethodImplementation(perceivedClass, ObjCSelector.methodSignatureForSelector)
		let methodSignatureForSelector = unsafeBitCast(impl, to: SuperMethodSignatureForSelector.self)
		return methodSignatureForSelector(objectRef, ObjCSelector.methodSignatureForSelector, selector)
	}

	_ = class_replaceMethod(realClass,
	                        ObjCSelector.methodSignatureForSelector,
	                        imp_implementationWithBlock(newMethodSignatureForSelector as Any),
	                        ObjCMethodEncoding.methodSignatureForSelector)
}

internal final class SelectorCache {
	private var map: [Selector: (main: Selector, interop: Selector)] = [:]

	init() {}

	/// Cache the aliases of the specified selector in the cache.
	///
	/// - warning: Any invocation of this method must be synchronized against the
	///            runtime subclass.
	@discardableResult
	func cache(_ selector: Selector) -> (main: Selector, interop: Selector) {
		if let pair = map[selector] {
			return pair
		}

		let aliases = (selector.alias, selector.interopAlias)
		map[selector] = aliases

		return aliases
	}

	/// Get the alias of the specified selector.
	///
	/// - parameters:
	///   - selector: The selector alias.
	func alias(for selector: Selector) -> Selector {
		if let (main, _) = map[selector] {
			return main
		}

		return selector.alias
	}

	/// Get the secondary alias of the specified selector.
	///
	/// - parameters:
	///   - selector: The selector alias.
	func interopAlias(for selector: Selector) -> Selector {
		if let (_, interop) = map[selector] {
			return interop
		}

		return selector.interopAlias
	}
}

// The signature cache for classes that have been swizzled for method
// interception.
//
// Read-copy-update is used here, since the cache has multiple readers but only
// one writer.
internal final class SignatureCache {
	// `Dictionary` takes 8 bytes for the reference to its storage and does CoW.
	// So it should not encounter any corrupted, partially updated state.
	private var map: [Selector: AnyObject] = [:]

	init() {}

	/// Get or set the signature for the specified selector.
	///
	/// - warning: Any invocation of the setter must be synchronized against the
	///            runtime subclass.
	///
	/// - parameters:
	///   - selector: The method signature.
	subscript(selector: Selector) -> AnyObject? {
		get {
			return map[selector]
		}
		set {
			if map[selector] == nil {
				map[selector] = newValue
			}
		}
	}
}
