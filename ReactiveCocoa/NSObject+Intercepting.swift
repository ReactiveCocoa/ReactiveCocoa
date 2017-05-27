import Foundation
import ReactiveSwift
import enum Result.NoError

/// Whether the runtime subclass has already been prepared for method
/// interception.
fileprivate let interceptedKey = AssociationKey(default: false)

/// Holds the method signature and selector cache of the runtime subclass.
fileprivate let cacheKey = AssociationKey<(SignatureCache, SelectorCache, ThunkCache)>()

extension Reactive where Base: NSObject {
	/// Create a signal which sends a `next` event at the end of every 
	/// invocation of `selector` on the object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns: A trigger signal.
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		return base.intercept(selector).map { _ in }
	}

	/// Create a signal which sends a `next` event, containing an array of 
	/// bridged arguments, at the end of every invocation of `selector` on the 
	/// object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns: A signal that sends an array of bridged arguments.
	public func signal(for selector: Selector) -> Signal<[Any?], NoError> {
		return base.intercept(selector).map(unpackInvocation)
	}
}

extension NSObject {
	/// Setup the method interception.
	///
	/// - parameters:
	///   - object: The object to be intercepted.
	///   - selector: The selector of the method to be intercepted.
	///
	/// - returns: A signal that sends the corresponding `NSInvocation` after 
	///            every invocation of the method.
	@nonobjc fileprivate func intercept(_ selector: Selector) -> Signal<AnyObject, NoError> {
		guard let method = class_getInstanceMethod(objcClass, selector) else {
			fatalError("Selector `\(selector)` does not exist in class `\(String(describing: objcClass))`.")
		}

		let typeEncoding = method_getTypeEncoding(method)!
		assert(checkTypeEncoding(typeEncoding))

		return synchronized {
			let alias = selector.alias
			let stateKey = AssociationKey<InterceptingState?>(alias)

			if let state = associations.value(forKey: stateKey) {
				return state.signal
			}

			let subclass: AnyClass = swizzleClass(self)
			let perceivedClass: AnyClass = (subclass as AnyObject).objcClass
			let subclassAssociations = Associations(subclass as AnyObject)

			// FIXME: Compiler asks to handle a mysterious throw.
			try! ReactiveCocoa.synchronized(subclass) {
				let isSwizzled = subclassAssociations.value(forKey: interceptedKey)

				let signatureCache: SignatureCache
				let selectorCache: SelectorCache
				let thunkCache: ThunkCache

				if isSwizzled {
					(signatureCache, selectorCache, thunkCache) = subclassAssociations.value(forKey: cacheKey)
				} else {
					signatureCache = SignatureCache()
					selectorCache = SelectorCache()
					thunkCache = ThunkCache()

					subclassAssociations.setValue((signatureCache, selectorCache, thunkCache), forKey: cacheKey)
					subclassAssociations.setValue(true, forKey: interceptedKey)

					enableMessageForwarding(subclass, selectorCache)
					setupMethodSignatureCaching(subclass, signatureCache)
				}

				selectorCache.cache(selector)

				let signature = signatureCache[selector] ?? {
					let signature = NSMethodSignature.signature(withObjCTypes: typeEncoding)
					signatureCache[selector] = signature
					return signature
				}()

				let currentDynamicImpl = class_getImmediateMethod(subclass, selector)
					.flatMap(method_getImplementation)

				if let generatedImpl = thunkCache[selector]?.impl {
					// The interception has already been enabled.
					precondition(currentDynamicImpl == generatedImpl, incompatibleExternalIsaSwizzlingError(for: selector))
				} else if let matchingGenerator = getInterceptor(for: typeEncoding), currentDynamicImpl != _rac_objc_msgForward {
					// RAC has a predefined implementation generator for this method
					// signature.
					let config = ThunkConfiguration(stateKey: stateKey,
					                                selector: selector,
					                                methodSignature: signature,
					                                originalImplementation: currentDynamicImpl,
					                                perceivedClass: perceivedClass)
					let imp = imp_implementationWithBlock(matchingGenerator(config))!
					thunkCache[selector] = (imp, currentDynamicImpl)

					// Enable messages interception for the selector.
					let previousImpl = class_replaceMethod(subclass, selector, imp, typeEncoding)
					precondition(previousImpl == currentDynamicImpl, incompatibleExternalIsaSwizzlingError(for: selector))
				} else {
					// Start forwarding the messages of the selector.
					_ = class_replaceMethod(subclass, selector, _rac_objc_msgForward, typeEncoding)
				}
			}

			let state = InterceptingState(lifetime: reactive.lifetime)
			associations.setValue(state, forKey: stateKey)

			return state.signal
		}
	}
}

extension NSObject {
	/// Swizzle the given selectors.
	///
	/// - warning: The swizzling **does not** apply on a per-instance basis. In
	///            other words, repetitive swizzling of the same selector would
	///            overwrite previous swizzling attempts, despite a different
	///            instance being supplied.
	///
	/// - parameters:
	///   - pairs: Tuples of selectors and the respective implementions to be
	///            swapped in.
	///   - key: An association key which determines if the swizzling has already
	///          been performed.
	internal func swizzle(_ pairs: (Selector, Any)..., key hasSwizzledKey: AssociationKey<Bool>) {
		let subclass: AnyClass = swizzleClass(self)
		let perceivedClass: AnyClass = (subclass as AnyObject).objcClass

		try! ReactiveCocoa.synchronized(subclass) {
			let subclassAssociations = Associations(subclass as AnyObject)

			if !subclassAssociations.value(forKey: hasSwizzledKey) {
				subclassAssociations.setValue(true, forKey: hasSwizzledKey)

				func swizzleNormally(_ selector: Selector, _ impl: IMP) {
					let method = class_getInstanceMethod(subclass, selector)
					let typeEncoding = method_getTypeEncoding(method)!

					let succeeds = class_addMethod(subclass, selector, impl, typeEncoding)
					precondition(succeeds, incompatibleExternalIsaSwizzlingError(for: selector))
				}

				let isIntercepted = subclassAssociations.value(forKey: interceptedKey)

				if isIntercepted {
					let (signatureCache, _, thunkCache) = subclassAssociations.value(forKey: cacheKey)

					for (selector, body) in pairs {
						if let (oldThunkImpl, knownDynamicImpl) = thunkCache[selector] {
							precondition(knownDynamicImpl == nil, incompatibleExternalIsaSwizzlingError(for: selector))

							// Since RAC already swizzled the selector and provided a
							// thunk, a new thunk has to be created to inject the new
							// implementation we have.

							let stateKey = AssociationKey<InterceptingState?>(selector.alias)
							let method = class_getInstanceMethod(subclass, selector)
							let typeEncoding = method_getTypeEncoding(method)!
							let impl = imp_implementationWithBlock(body)

							let config = ThunkConfiguration(stateKey: stateKey,
							                                selector: selector,
							                                methodSignature: signatureCache[selector]!,
							                                originalImplementation: impl,
							                                perceivedClass: perceivedClass)

							let thunkImpl = imp_implementationWithBlock(getInterceptor(for: typeEncoding)!(config))!
							thunkCache[selector] = (thunkImpl, impl)

							// Swap in the new thunk.
							let previousImpl = class_replaceMethod(subclass, selector, thunkImpl, typeEncoding)
							precondition(previousImpl == oldThunkImpl, incompatibleExternalIsaSwizzlingError(for: selector))

							imp_removeBlock(oldThunkImpl)
						} else {
							swizzleNormally(selector, imp_implementationWithBlock(body))
						}
					}
				} else {
					for (selector, body) in pairs {
						swizzleNormally(selector, imp_implementationWithBlock(body))
					}
				}
			}
		}
	}
}

/// Swizzle `realClass` to enable message forwarding for method interception.
///
/// - parameters:
///   - realClass: The runtime subclass to be swizzled.
private func enableMessageForwarding(_ realClass: AnyClass, _ selectorCache: SelectorCache) {
	let perceivedClass: AnyClass = class_getSuperclass(realClass)

	typealias ForwardInvocationImpl = @convention(block) (Unmanaged<NSObject>, AnyObject) -> Void
	let newForwardInvocation: ForwardInvocationImpl = { objectRef, invocation in
		let selector = invocation.selector!
		let alias = selectorCache.alias(for: selector)

		defer {
			let stateKey = AssociationKey<InterceptingState?>(alias)
			if let state = objectRef.takeUnretainedValue().associations.value(forKey: stateKey) {
				state.observer.send(value: invocation)
			}
		}

		let method = class_getInstanceMethod(perceivedClass, selector)!
		let typeEncoding = method_getTypeEncoding(method)

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

/// The state of an intercepted method specific to an instance.
internal final class InterceptingState {
	let (signal, observer) = Signal<AnyObject, NoError>.pipe()

	/// Initialize a state specific to an instance.
	///
	/// - parameters:
	///   - lifetime: The lifetime of the instance.
	init(lifetime: Lifetime) {
		lifetime.ended.observeCompleted(observer.sendCompleted)
	}
}

private final class SelectorCache {
	private var map: [Selector: Selector] = [:]

	init() {}

	/// Cache the alias of the specified selector in the cache.
	///
	/// - warning: Any invocation of this method must be synchronized against the
	///            runtime subclass.
	@discardableResult
	func cache(_ selector: Selector) -> Selector {
		if let alias = map[selector] {
			return alias
		}

		let aliases = selector.alias
		map[selector] = aliases

		return aliases
	}

	/// Get the alias of the specified selector.
	///
	/// - parameters:
	///   - selector: The selector alias.
	func alias(for selector: Selector) -> Selector {
		if let alias = map[selector] {
			return alias
		}

		return selector.alias
	}
}

// The signature cache for classes that have been swizzled for method
// interception.
//
// Read-copy-update is used here, since the cache has multiple readers but only
// one writer.
private final class SignatureCache {
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
	///   - selector: The method selector.
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

// The thunk cache for classes that have been swizzled for method interception.
//
// Read-copy-update is used here, since the cache has multiple readers but only
// one writer.
private final class ThunkCache {
	// `Dictionary` takes 8 bytes for the reference to its storage and does CoW.
	// So it should not encounter any corrupted, partially updated state.
	private var map: [Selector: (impl: IMP, knownDynamicImpl: IMP?)] = [:]

	init() {}

	/// Get or set the thunk for the specified selector.
	///
	/// - warning: Any invocation of the setter must be synchronized against the
	///            runtime subclass.
	///
	/// - parameters:
	///   - selector: The method selector.
	subscript(selector: Selector) -> (impl: IMP, knownDynamicImpl: IMP?)? {
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

/// Assert that the method does not contain types that cannot be intercepted.
///
/// - parameters:
///   - types: The type encoding C string of the method.
///
/// - returns: `true`.
private func checkTypeEncoding(_ types: UnsafePointer<CChar>) -> Bool {
	// Some types, including vector types, are not encoded. In these cases the
	// signature starts with the size of the argument frame.
	assert(types.pointee < Int8(UInt8(ascii: "1")) || types.pointee > Int8(UInt8(ascii: "9")),
	       "unknown method return type not supported in type encoding: \(String(cString: types))")

	assert(types.pointee != Int8(UInt8(ascii: "(")), "union method return type not supported")
	assert(types.pointee != Int8(UInt8(ascii: "{")), "struct method return type not supported")
	assert(types.pointee != Int8(UInt8(ascii: "[")), "array method return type not supported")

	assert(types.pointee != Int8(UInt8(ascii: "j")), "complex method return type not supported")

	return true
}

/// Extract the arguments of an `NSInvocation` as an array of objects.
///
/// - parameters:
///   - invocation: The `NSInvocation` to unpack.
///
/// - returns: An array of objects.
private func unpackInvocation(_ invocation: AnyObject) -> [Any?] {
	let invocation = invocation as AnyObject
	let methodSignature = invocation.objcMethodSignature!
	let count = UInt(methodSignature.numberOfArguments!)

	var bridged = [Any?]()
	bridged.reserveCapacity(Int(count - 2))

	// Ignore `self` and `_cmd` at index 0 and 1.
	for position in 2 ..< count {
		let rawEncoding = methodSignature.argumentType(at: position)
		let encoding = ObjCTypeEncoding(rawValue: rawEncoding.pointee) ?? .undefined

		func extract<U>(_ type: U.Type) -> U {
			let pointer = UnsafeMutableRawPointer.allocate(bytes: MemoryLayout<U>.size,
			                                               alignedTo: MemoryLayout<U>.alignment)
			defer {
				pointer.deallocate(bytes: MemoryLayout<U>.size,
				                   alignedTo: MemoryLayout<U>.alignment)
			}

			invocation.copy(to: pointer, forArgumentAt: Int(position))
			return pointer.assumingMemoryBound(to: type).pointee
		}

		let value: Any?

		switch encoding {
		case .char:
			value = NSNumber(value: extract(CChar.self))
		case .int:
			value = NSNumber(value: extract(CInt.self))
		case .short:
			value = NSNumber(value: extract(CShort.self))
		case .long:
			value = NSNumber(value: extract(CLong.self))
		case .longLong:
			value = NSNumber(value: extract(CLongLong.self))
		case .unsignedChar:
			value = NSNumber(value: extract(CUnsignedChar.self))
		case .unsignedInt:
			value = NSNumber(value: extract(CUnsignedInt.self))
		case .unsignedShort:
			value = NSNumber(value: extract(CUnsignedShort.self))
		case .unsignedLong:
			value = NSNumber(value: extract(CUnsignedLong.self))
		case .unsignedLongLong:
			value = NSNumber(value: extract(CUnsignedLongLong.self))
		case .float:
			value = NSNumber(value: extract(CFloat.self))
		case .double:
			value = NSNumber(value: extract(CDouble.self))
		case .bool:
			value = NSNumber(value: extract(CBool.self))
		case .object:
			value = extract((AnyObject?).self)
		case .type:
			value = extract((AnyClass?).self)
		case .selector:
			value = extract((Selector?).self)
		case .undefined:
			var size = 0, alignment = 0
			NSGetSizeAndAlignment(rawEncoding, &size, &alignment)
			let buffer = UnsafeMutableRawPointer.allocate(bytes: size, alignedTo: alignment)
			defer { buffer.deallocate(bytes: size, alignedTo: alignment) }

			invocation.copy(to: buffer, forArgumentAt: Int(position))
			value = NSValue(bytes: buffer, objCType: rawEncoding)
		}

		bridged.append(value)
	}

	return bridged
}

private func incompatibleExternalIsaSwizzlingError(for selector: Selector) -> String {
	return "RAC detected an incompatible isa-swizzling operation on the selector `\(selector)`."
}
