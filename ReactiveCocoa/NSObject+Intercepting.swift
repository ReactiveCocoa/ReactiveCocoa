import Foundation
import ReactiveSwift
import enum Result.NoError

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
		assertSupportedSignature(typeEncoding)

		return synchronized {
			let alias = selector.alias
			let stateKey = AssociationKey<InterceptingState?>(alias)
			let interopAlias = selector.interopAlias

			if let state = associations.value(forKey: stateKey) {
				return state.signal
			}

			let subclass: AnyClass = enableMessageForwarding { subclass, selectorCache, signatureCache in
				selectorCache.cache(selector)

				if signatureCache[selector] == nil {
					let signature = NSMethodSignature.signature(withObjCTypes: typeEncoding)
					signatureCache[selector] = signature
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
						.flatMap { $0 != _rac_objc_msgForward ? $0 : nil }

					if let impl = immediateImpl {
						let succeeds = class_addMethod(subclass, interopAlias, impl, typeEncoding)
						precondition(succeeds, "RAC attempts to swizzle a selector that has message forwarding enabled with a runtime injected implementation. This is unsupported in the current version.")
					}
				}
			}

			let state = InterceptingState(lifetime: reactive.lifetime)
			associations.setValue(state, forKey: stateKey)

			// Start forwarding the messages of the selector.
			_ = class_replaceMethod(subclass, selector, _rac_objc_msgForward, typeEncoding)

			return state.signal
		}
	}
}

internal func interceptingObject(_ object: Unmanaged<NSObject>, didInvokeSelectorOfAlias alias: Selector, with invocation: AnyObject) {
	let stateKey = AssociationKey<InterceptingState?>(alias)
	if let state = object.takeUnretainedValue().associations.value(forKey: stateKey) {
		state.observer.send(value: invocation)
	}
}

/// The state of an intercepted method specific to an instance.
private final class InterceptingState {
	let (signal, observer) = Signal<AnyObject, NoError>.pipe()

	/// Initialize a state specific to an instance.
	///
	/// - parameters:
	///   - lifetime: The lifetime of the instance.
	init(lifetime: Lifetime) {
		lifetime.ended.observeCompleted(observer.sendCompleted)
	}
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
