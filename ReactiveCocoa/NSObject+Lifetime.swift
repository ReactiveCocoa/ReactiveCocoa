import Foundation
import ReactiveSwift

private var lifetimeKey: UInt8 = 0
private var lifetimeTokenKey: UInt8 = 0

extension Reactive where Base: NSObject {
	/// Returns a lifetime that ends when the object is deallocated.
	@nonobjc public var lifetime: Lifetime {
		return base.synchronized {
			if let lifetime = objc_getAssociatedObject(base, &lifetimeKey) as! Lifetime? {
				return lifetime
			}

			let token = Lifetime.Token()
			let lifetime = Lifetime(token)

			let objcClass: AnyClass = (base as AnyObject).objcClass
			let deallocSelector = sel_registerName("dealloc")!

			// Swizzle `-dealloc` so that the lifetime token is released at the
			// beginning of the deallocation chain, and only after the KVO `-dealloc`.
			objc_sync_enter(objcClass)
			if objc_getAssociatedObject(objcClass, &lifetimeKey) == nil {
				objc_setAssociatedObject(objcClass, &lifetimeKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

				var existingImpl: IMP? = nil

				let newImplBlock: @convention(block) (UnsafeRawPointer) -> Void = { objectRef in
					_rac_objc_setAssociatedObject(objectRef, &lifetimeTokenKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

					let impl: IMP

					if let existingImpl = existingImpl {
						impl = existingImpl
					} else {
						let superclass: AnyClass = class_getSuperclass(objcClass)
						impl = class_getMethodImplementation(superclass, deallocSelector)
					}

					typealias Impl = @convention(c) (UnsafeRawPointer, Selector) -> Void
					unsafeBitCast(impl, to: Impl.self)(objectRef, deallocSelector)
				}

				let newImpl =  imp_implementationWithBlock(newImplBlock as Any)

				if !class_addMethod(objcClass, deallocSelector, newImpl, "v@:") {
					// The class has an existing `dealloc`. Preserve that as `existingImpl`.
					let deallocMethod = class_getInstanceMethod(objcClass, deallocSelector)
					existingImpl = method_getImplementation(deallocMethod)
					existingImpl = method_setImplementation(deallocMethod, newImpl)
				}
			}
			objc_sync_exit(objcClass)

			objc_setAssociatedObject(base, &lifetimeTokenKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			objc_setAssociatedObject(base, &lifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

			return lifetime
		}
	}
}

@objc private protocol ObjCClassReporting {
	@objc(class)
	var objcClass: AnyClass { get }
}
