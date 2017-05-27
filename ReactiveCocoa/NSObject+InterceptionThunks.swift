#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Naming convention: makeThunk[First Argument Type][Second Argument Type]...

private var interceptorGenerators: [String: (ThunkConfiguration) -> Any] = {
	var configurations: [String: (ThunkConfiguration) -> Any] = [
		// Setters of automatic KVO compliant properties, and void-returning
		// single-argument ObjC methods.
		"v@:c": makeThunkInt8,
		"v@:i": makeThunkCInt,
		"v@:s": makeThunkInt16,
		"v@:l": makeThunkInt32,
		"v@:q": makeThunkInt64,
		"v@:C": makeThunkUInt8,
		"v@:I": makeThunkCUnsignedInt,
		"v@:S": makeThunkUInt16,
		"v@:L": makeThunkUInt32,
		"v@:Q": makeThunkUInt64,
		"v@:B": makeThunkBool,
		"v@:@": makeThunkAnyObject,
		"v@:f": makeThunkFloat,
		"v@:d": makeThunkDouble]

	#if arch(i386) || arch(arm)
		configurations["v@:{CGRect={CGPoint=ff}{CGSize=ff}}"] = makeThunkCGRect
		configurations["v@:{CGPoint=ff}"] = makeThunkCGPoint
		configurations["v@:{CGSize=ff}"] = makeThunkCGSize
		configurations["v@:{NSRange=LL}"] = makeThunkNSRange
	#else
		configurations["v@:{CGRect={CGPoint=dd}{CGSize=dd}}"] = makeThunkCGRect
		configurations["v@:{CGPoint=dd}"] = makeThunkCGPoint
		configurations["v@:{CGSize=dd}"] = makeThunkCGSize
		configurations["v@:{NSRange=QQ}"] = makeThunkNSRange
	#endif

	return configurations
}()

internal func getInterceptor(for typeEncoding: UnsafePointer<CChar>) -> ((ThunkConfiguration) -> Any)? {
	func clean(_ typeEncoding: UnsafePointer<Int8>) -> String {
		return String(String(cString: typeEncoding)
			.characters.filter { !"0123456789".characters.contains($0) })
	}

	return interceptorGenerators[clean(typeEncoding)]
}

internal struct ThunkConfiguration {
	fileprivate let stateKey: AssociationKey<InterceptingState?>
	fileprivate let selector: Selector
	fileprivate let methodSignature: AnyObject
	fileprivate let originalImplementation: IMP?
	fileprivate let perceivedClass: AnyClass

	init(stateKey: AssociationKey<InterceptingState?>, selector: Selector, methodSignature: AnyObject, originalImplementation: IMP?, perceivedClass: AnyClass) {
		self.stateKey = stateKey
		self.selector = selector
		self.methodSignature = methodSignature
		self.originalImplementation = originalImplementation
		self.perceivedClass = perceivedClass
	}

	fileprivate func getImplementation() -> IMP? {
		let impl = originalImplementation ?? class_getMethodImplementation(perceivedClass, selector)
		return impl.flatMap { $0 != _rac_objc_msgForward ? $0 : nil }
	}

	fileprivate func forward(_ object: Unmanaged<AnyObject>, noConcreteImpl: Bool, pack: (ObjCInvocation) -> Void) {
		let invocation = NSInvocation.invocation(withMethodSignature: methodSignature)
		invocation.target = object
		invocation.setSelector(selector)
		pack(invocation)

		if noConcreteImpl {
			typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, AnyObject) -> Void
			let impl = class_getMethodImplementation(perceivedClass, ObjCSelector.forwardInvocation)
			let superImplementation = unsafeBitCast(impl, to: CImplementation.self)
			superImplementation(object, ObjCSelector.forwardInvocation, invocation)
		}

		if let state = Associations(object.takeUnretainedValue()).value(forKey: stateKey) {
			state.observer.send(value: invocation)
		}
	}
}

private func makeThunkBool(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Bool) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Bool) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkInt8(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Int8) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Int8) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkDouble(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Double) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Double) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkFloat(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Float) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Float) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkCInt(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, CInt) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, CInt) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkInt64(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Int64) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Int64) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkInt32(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Int32) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Int32) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkAnyObject(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, AnyObject) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, AnyObject) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkCGPoint(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, CGPoint) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, CGPoint) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkNSRange(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, NSRange) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, NSRange) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkCGRect(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, CGRect) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, CGRect) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkInt16(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, Int16) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, Int16) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkCGSize(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, CGSize) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, CGSize) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkUInt8(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, UInt8) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, UInt8) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkCUnsignedInt(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, CUnsignedInt) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, CUnsignedInt) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkUInt64(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, UInt64) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, UInt64) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkUInt32(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, UInt32) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, UInt32) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}

private func makeThunkUInt16(config: ThunkConfiguration) -> (@convention(block) (Unmanaged<AnyObject>, UInt16) -> Void) {
	return { object, value in
		typealias CImplementation = @convention(c) (Unmanaged<AnyObject>, Selector, UInt16) -> Void
		var noConcreteImpl = false

		if let impl = config.getImplementation() {
			unsafeBitCast(impl, to: CImplementation.self)(object, config.selector, value)
		} else {
			noConcreteImpl = true
		}

		config.forward(object, noConcreteImpl: noConcreteImpl) { invocation in
			var value = value
			invocation.setArgument(&value, at: 2)
		}
	}
}
