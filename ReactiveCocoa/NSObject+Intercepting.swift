import Foundation
import ReactiveSwift
import enum Result.NoError

/// Whether the runtime subclass has already been prepared for method
/// interception.
fileprivate let interceptedKey = AssociationKey(default: false)

/// Holds the method signature cache of the runtime subclass.
fileprivate let signatureCacheKey = AssociationKey<SignatureCache>()

/// Holds the method selector cache of the runtime subclass.
fileprivate let selectorCacheKey = AssociationKey<SelectorCache>()

/// Holds the template cache of the runtime subclass.
fileprivate let templateCacheKey = AssociationKey<[Selector: IMP]>(default: [:])

extension Reactive where Base: NSObject {
	/// Create a signal which sends a `next` event at the end of every invocation
	/// of `selector` on the object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns:
	///   A trigger signal.
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		return base.intercept(selector, wantsArguments: false).map { _ in }
	}

	/// Create a signal which sends a `next` event, containing an array of bridged
	/// arguments, at the end of every invocation of `selector` on the object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns:
	///   A signal that sends an array of bridged arguments.
	public func signal(for selector: Selector) -> Signal<[Any?], NoError> {
		// FIXME: Use `map(!)` when the compiler doesn't resolve `!` to the boolean
		//        `!`.
		return base.intercept(selector, wantsArguments: true).map { $0! }
	}
}

extension NSObject {
	/// Setup the method interception.
	///
	/// - parameters:
	///   - object: The object to be intercepted.
	///   - selector: The selector of the method to be intercepted.
	///
	/// - returns:
	///   A signal that sends the corresponding `NSInvocation` after every
	///   invocation of the method.
	@nonobjc fileprivate func intercept(_ selector: Selector, wantsArguments: Bool) -> Signal<[Any?]?, NoError> {
		guard let method = class_getInstanceMethod(objcClass, selector) else {
			fatalError("Selector `\(selector)` does not exist in class `\(String(describing: objcClass))`.")
		}

		let typeEncoding = method_getTypeEncoding(method)!
		assert(checkTypeEncoding(typeEncoding))

		return synchronized {
			let alias = selector.alias
			let interopAlias = selector.interopAlias
			let stateKey = AssociationKey<InterceptingState?>(interopAlias)

			if let state = associations.value(forKey: stateKey) {
				if wantsArguments {
					state.wantsArguments()
				}
				return state.signal
			}

			let subclass: AnyClass = swizzleClass(self)
			let subclassAssociations = Associations(subclass as AnyObject)

			var signature: AnyObject!

			// FIXME: Compiler asks to handle a mysterious throw.
			let templateImpl: IMP? = try! ReactiveCocoa.synchronized(subclass) {
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

					enableMessageForwarding(subclass, selectorCache)
					setupMethodSignatureCaching(subclass, signatureCache)
				}

				selectorCache.cache(selector)

				if let s = signatureCache[selector] {
					signature = s
				} else {
					signature = NSMethodSignature.signature(withObjCTypes: typeEncoding)
					signatureCache[selector] = signature
				}

				let templateImpl: IMP?

				if let generator = InterceptionTemplate.template(forTypeEncoding: typeEncoding) {
					var templateCache = subclassAssociations.value(forKey: templateCacheKey)
					if let impl = templateCache[selector] {
						templateImpl = impl
					} else {
						templateImpl = generator(subclass.objcClass, subclass, selector, interopAlias, Unmanaged.passUnretained(signature))
						if templateImpl != nil {
							templateCache[selector] = templateImpl
							subclassAssociations.setValue(templateCache, forKey: templateCacheKey)
						}
					}
				} else {
					templateImpl = nil
				}

				// If an immediate implementation of the selector is found in the
				// runtime subclass the first time the selector is intercepted,
				// preserve the implementation.
				//
				// Example: KVO setters if the instance is swizzled by KVO before RAC
				//          does.
				if !class_respondsToSelector(subclass, interopAlias) {
					let immediateImpl = class_getImmediateMethod(subclass, selector)
						.flatMap(method_getImplementation)
						.flatMap { $0 != _rac_objc_msgForward && $0 != templateImpl ? $0 : nil }

					if let impl = immediateImpl {
						class_addMethod(subclass, interopAlias, impl, typeEncoding)
					}
				}

				return templateImpl
			}

			let state = InterceptingState(lifetime: reactive.lifetime)
			if wantsArguments {
				state.wantsArguments()
			}
			associations.setValue(state, forKey: stateKey)

			if let impl = templateImpl {
				_ = class_replaceMethod(subclass, selector, impl, typeEncoding)
			} else {
				// Start forwarding the messages of the selector.
				_ = class_replaceMethod(subclass, selector, _rac_objc_msgForward, typeEncoding)
			}
			
			return state.signal
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
		let interopAlias = selectorCache.interopAlias(for: selector)

		defer {
			let stateKey = AssociationKey<InterceptingState?>(interopAlias)
			if let state = objectRef.takeUnretainedValue().associations.value(forKey: stateKey) {
				state.send(state.packsArguments ? unpackInvocation(invocation) : nil)
			}
		}

		let method = class_getInstanceMethod(perceivedClass, selector)!
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

			let interopImpl = class_getMethodImplementation(realClass, interopAlias)
			let previousImpl = class_replaceMethod(realClass, selector, interopImpl, typeEncoding)
			invocation.invoke()
			_ = class_replaceMethod(realClass, selector, previousImpl, typeEncoding)

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
private final class InterceptingState {
	fileprivate let signal: Signal<[Any?]?, NoError>
	private let observer: Signal<[Any?]?, NoError>.Observer
	private(set) var packsArguments = false

	/// Initialize a state specific to an instance.
	///
	/// - parameters:
	///   - lifetime: The lifetime of the instance.
	init(lifetime: Lifetime) {
		(signal, observer) = Signal<[Any?]?, NoError>.pipe()
		lifetime.ended.observeCompleted(observer.sendCompleted)
	}

	func wantsArguments() {
		packsArguments = true
	}

	func send(_ values: [Any?]?) {
		observer.send(value: values)
	}
}

private final class SelectorCache {
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

/// Assert that the method does not contain types that cannot be intercepted.
///
/// - parameters:
///   - types: The type encoding C string of the method.
///
/// - returns:
///   `true`.
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
/// - returns:
///   An array of objects.
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

private class InterceptionTemplate {
	// Implementation Note:
	//
	// This combination was benckmarked to be consistently the fastest. Packing
	// other arguments into `SelectorAliases` might cause a regression in single
	// digit percentage.
	typealias Template = (_ perceived: AnyClass, _ real: AnyClass, _ selector: Selector, _ interopAlias: Selector, _ methodSignature: Unmanaged<AnyObject>) -> IMP

	private static let shared: [String: Template] = [
		"v@:": _v0_id_sel,
		"v@:c": _v0_id_sel_i8,
		"v@:l": _v0_id_sel_i32,
		"v@:q": _v0_id_sel_i64,
		"v@:@": _v0_id_sel_id,
		"v@:@q": _v0_id_sel_id_i64,
		"v@:@l": _v0_id_sel_id_i32,
		"v@:@d": _v0_id_sel_id_f64,
		"v@:@f": _v0_id_sel_id_f32,
		"v@:@@": _v0_id_sel_id_id,
		"v@:@@q": _v0_id_sel_id_id_i64,
		"v@:@@@": _v0_id_sel_id_id_id
	]

	static func template(forTypeEncoding types: UnsafePointer<Int8>) -> Template? {
		var iterator = types
		var characters = [UInt8]()

		let nul = Int8(UInt8(ascii: "\0"))
		let zero = Int8(UInt8(ascii: "0"))
		let nine = Int8(UInt8(ascii: "9"))

		while iterator.pointee != nul {
			characters.append(UInt8(iterator.pointee))
			iterator = NSGetSizeAndAlignment(iterator, nil, nil)
			while !(iterator.pointee < zero || iterator.pointee > nine) {
				iterator += 1
			}
		}

		let cleanEncoding = String(bytes: characters, encoding: .ascii)!
		return shared[cleanEncoding]
	}
}

private final class SelectorAliases {
	let alias: Selector
	let interopAlias: Selector

	init(alias: Selector, interopAlias: Selector) {
		self.alias = alias
		self.interopAlias = interopAlias
	}
}

private typealias SuperForwardInvocation = @convention(c) (Unmanaged<NSObject>, Selector, AnyObject) -> Void

private enum Implementation<Impl> {
	case method(Impl)
	case forward(SuperForwardInvocation)
}

private func getImplementation<Impl>(_ perceivedClass: AnyClass, _ realClass: AnyClass, _ selector: Selector, _ interopAlias: Selector, _ type: Impl.Type) -> Implementation<Impl> {
	let method = class_getInstanceMethod(perceivedClass, selector)!

	if class_respondsToSelector(realClass, interopAlias) {
		let interopImpl = class_getMethodImplementation(realClass, interopAlias)!
		return .method(unsafeBitCast(interopImpl, to: Impl.self))
	} else if let impl = method_getImplementation(method), impl != _rac_objc_msgForward {
		return .method(unsafeBitCast(impl, to: Impl.self))
	} else {
		let impl = class_getMethodImplementation(perceivedClass, ObjCSelector.forwardInvocation)
		let forwardInvocation = unsafeBitCast(impl, to: SuperForwardInvocation.self)
		return .forward(forwardInvocation)
	}
}

private func getState(_ objectRef: Unmanaged<NSObject>, for interopAlias: Selector) -> InterceptingState? {
	let stateKey = AssociationKey<InterceptingState?>(interopAlias)
	return objectRef.takeUnretainedValue().associations.value(forKey: stateKey)
}

private func packInvocation(
	_ target: Unmanaged<NSObject>,
	_ selector: Selector,
	_ signature: Unmanaged<AnyObject>
) -> AnyObject {
	let invocation = NSInvocation.invocation(withMethodSignature: signature.takeUnretainedValue())
	invocation.setUnmanagedTarget(target)
	invocation.setSelector(selector)
	return invocation
}

private func packInvocation<A>(
	_ target: Unmanaged<NSObject>,
	_ selector: Selector,
	_ signature: Unmanaged<AnyObject>,
	_ first: A
) -> AnyObject {
	let invocation = NSInvocation.invocation(withMethodSignature: signature.takeUnretainedValue())
	invocation.setUnmanagedTarget(target)
	invocation.setSelector(selector)
	var first = first
	invocation.copy(from: &first, forArgumentAt: 2)
	return invocation
}

private func packInvocation<A, B>(
	_ target: Unmanaged<NSObject>,
	_ selector: Selector,
	_ signature: Unmanaged<AnyObject>,
	_ first: A,
	_ second: B
) -> AnyObject {
	let invocation = NSInvocation.invocation(withMethodSignature: signature.takeUnretainedValue())
	invocation.setUnmanagedTarget(target)
	invocation.setSelector(selector)
	var first = first
	var second = second
	invocation.copy(from: &first, forArgumentAt: 2)
	invocation.copy(from: &second, forArgumentAt: 3)
	return invocation
}

private func packInvocation<A, B, C>(
	_ target: Unmanaged<NSObject>,
	_ selector: Selector,
	_ signature: Unmanaged<AnyObject>,
	_ first: A,
	_ second: B,
	_ third: C
) -> AnyObject {
	let invocation = NSInvocation.invocation(withMethodSignature: signature.takeUnretainedValue())
	invocation.setUnmanagedTarget(target)
	invocation.setSelector(selector)
	var first = first
	var second = second
	var third = third
	invocation.copy(from: &first, forArgumentAt: 2)
	invocation.copy(from: &second, forArgumentAt: 3)
	invocation.copy(from: &third, forArgumentAt: 4)
	return invocation
}

private let _v0_id_sel: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>) -> Void = { objectRef in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_i8: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, CChar) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, CChar) -> Void = { objectRef, a in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_i32: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, CLong) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, CLong) -> Void = { objectRef, a in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_i64: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, CLongLong) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, CLongLong) -> Void = { objectRef, a in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?) -> Void = { objectRef, a in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue()] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_i64: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, CLongLong) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, CLongLong) -> Void = { objectRef, a, b in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_i32: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, CLong) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, CLong) -> Void = { objectRef, a, b in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_f64: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, CDouble) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, CDouble) -> Void = { objectRef, a, b in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_f32: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, CFloat) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, CFloat) -> Void = { objectRef, a, b in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_id: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?) -> Void = { objectRef, a, b in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b?.takeUnretainedValue()] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_id_i64: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?, CLongLong) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?, CLongLong) -> Void = { objectRef, a, b, c in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b, c)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b, c))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b?.takeUnretainedValue(), c] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}

private let _v0_id_sel_id_id_id: InterceptionTemplate.Template = { perceivedClass, realClass, selector, interopAlias, signature in
	typealias CImpl = @convention(c) (Unmanaged<NSObject>, Selector, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?) -> Void

	let impl: @convention(block) (Unmanaged<NSObject>, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?, Unmanaged<AnyObject>?) -> Void = { objectRef, a, b, c in
		switch getImplementation(perceivedClass, realClass, selector, interopAlias, CImpl.self) {
		case let .method(body): body(objectRef, selector, a, b, c)
		case let .forward(f): f(objectRef, ObjCSelector.forwardInvocation, packInvocation(objectRef, selector, signature, a, b, c))
		}

		if let state = getState(objectRef, for: interopAlias) {
			state.send(state.packsArguments ? [a?.takeUnretainedValue(), b?.takeUnretainedValue(), c?.takeUnretainedValue()] : nil)
		}
	}

	return imp_implementationWithBlock(impl as Any)
}
