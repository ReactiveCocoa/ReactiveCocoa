import Foundation
import ReactiveSwift

/// Holds the `Lifetime` of the object.
fileprivate let isSwizzledKey = AssociationKey<Bool>(default: false)

/// Holds the `Lifetime` of the object.
fileprivate let lifetimeKey = AssociationKey<Lifetime?>(default: nil)

/// Holds the `Lifetime.Token` of the object.
fileprivate let lifetimeTokenKey = AssociationKey<Lifetime.Token?>(default: nil)

internal func lifetime(of object: AnyObject) -> Lifetime {
	if let object = object as? NSObject {
		return object.reactive.lifetime
	}

	return synchronized(object) {
		let associations = Associations(object)

		if let lifetime = associations.value(forKey: lifetimeKey) {
			return lifetime
		}

		let (lifetime, token) = Lifetime.make()

		associations.setValue(token, forKey: lifetimeTokenKey)
		associations.setValue(lifetime, forKey: lifetimeKey)

		return lifetime
	}
}

extension Reactive where Base: NSObject {
	/// Returns a lifetime that ends when the object is deallocated.
	@nonobjc public var lifetime: Lifetime {
		return base.synchronized {
			if let lifetime = base.associations.value(forKey: lifetimeKey) {
				return lifetime
			}

			let (lifetime, token) = Lifetime.make()

			let objcClass: AnyClass = (base as AnyObject).objcClass
			let objcClassAssociations = Associations(objcClass as AnyObject)

			let deallocSelector = sel_registerName("dealloc")!

			// Swizzle `-dealloc` so that the lifetime token is released at the
			// beginning of the deallocation chain, and only after the KVO `-dealloc`.
			synchronized(objcClass) {
				// Swizzle the class only if it has not been swizzled before.
				if !objcClassAssociations.value(forKey: isSwizzledKey) {
					objcClassAssociations.setValue(true, forKey: isSwizzledKey)

					var existingImpl: IMP? = nil

					let newImplBlock: @convention(block) (UnsafeRawPointer) -> Void = { objectRef in
						// A custom trampoline of `objc_setAssociatedObject` is used, since
						// the imported version has been inserted with ARC calls that would
						// mess with the object deallocation chain.

						// Release the lifetime token.
						unsafeSetAssociatedValue(nil, forKey: lifetimeTokenKey, forObjectAt: objectRef)

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

			base.associations.setValue(token, forKey: lifetimeTokenKey)
			base.associations.setValue(lifetime, forKey: lifetimeKey)

			return lifetime
		}
	}
}
