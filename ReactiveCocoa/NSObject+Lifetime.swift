import Foundation
import ReactiveSwift

extension Reactive where Base: NSObject {
	/// Returns a lifetime that ends when the object is deallocated.
	@nonobjc public var lifetime: Lifetime {
		return base.synchronized {
			if let lifetime = base.associatedValue(forKey: AssociationKey.lifetime) as! Lifetime? {
				return lifetime
			}

			let token = Lifetime.Token()
			let lifetime = Lifetime(token)

			let objcClass: AnyClass = (base as AnyObject).objcClass
			let deallocSelector = sel_registerName("dealloc")!

			// Swizzle `-dealloc` so that the lifetime token is released at the
			// beginning of the deallocation chain, and only after the KVO `-dealloc`.
			synchronized(objcClass) {
				// Swizzle the class only if it has not been swizzled before.
				if objc_getAssociatedObject(objcClass, AssociationKey.lifetime) == nil {
					objc_setAssociatedObject(objcClass, AssociationKey.lifetime, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

					var existingImpl: IMP? = nil

					let newImplBlock: @convention(block) (UnsafeRawPointer) -> Void = { objectRef in
						// A custom trampoline of `objc_setAssociatedObject` is used, since
						// the imported version has been inserted with ARC calls that would
						// mess with the object deallocation chain.

						// Release the lifetime token.
						_rac_objc_setAssociatedObject(objectRef, AssociationKey.lifetimeToken, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

						let impl: IMP

						// Call the existing implementation if one has been caught. Otherwise,
						// call the one first available in the superclass hierarchy.
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

						// Store the existing implementation to `existingImpl` to ensure it is
						// available before our version is swapped in.
						existingImpl = method_getImplementation(deallocMethod)

						// Store the swapped-out implementation to `existingImpl` in case
						// the implementation has been changed concurrently.
						existingImpl = method_setImplementation(deallocMethod, newImpl)
					}
				}
			}

			base.setAssociatedValue(token, forKey: AssociationKey.lifetimeToken)
			base.setAssociatedValue(lifetime, forKey: AssociationKey.lifetime)

			return lifetime
		}
	}
}
