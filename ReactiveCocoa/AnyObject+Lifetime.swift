import Foundation
import ReactiveSwift

public extension Lifetime {
	public static func of(_ object: AnyObject) -> Lifetime {
		enum Keys {
			/// Holds the `Lifetime` of the object.
			static let isSwizzled = AssociationKey<Bool>(default: false)

			/// Holds the `Lifetime` of the object.
			static let lifetime = AssociationKey<Lifetime?>(default: nil)

			/// Holds the `Lifetime.Token` of the object.
			static let lifetimeToken = AssociationKey<Lifetime.Token?>(default: nil)
		}

		return synchronized(object) {
			if let object = object as? NSObject {
				if let lifetime = object.associations.value(forKey: Keys.lifetime) {
					return lifetime
				}

				let (lifetime, token) = Lifetime.make()

				let objcClass: AnyClass = (object as AnyObject).objcClass
				let objcClassAssociations = Associations(objcClass as AnyObject)

				#if swift(>=4.0)
				let deallocSelector = sel_registerName("dealloc")
				#else
				let deallocSelector = sel_registerName("dealloc")!
				#endif

				// Swizzle `-dealloc` so that the lifetime token is released at the
				// beginning of the deallocation chain, and only after the KVO `-dealloc`.
				synchronized(objcClass) {
					// Swizzle the class only if it has not been swizzled before.
					if !objcClassAssociations.value(forKey: Keys.isSwizzled) {
						objcClassAssociations.setValue(true, forKey: Keys.isSwizzled)

						var existingImpl: IMP? = nil

						let newImplBlock: @convention(block) (UnsafeRawPointer) -> Void = { objectRef in
							// A custom trampoline of `objc_setAssociatedObject` is used, since
							// the imported version has been inserted with ARC calls that would
							// mess with the object deallocation chain.

							// Release the lifetime token.
							unsafeSetAssociatedValue(nil, forKey: Keys.lifetimeToken, forObjectAt: objectRef)

							let impl: IMP

							// Call the existing implementation if one has been caught. Otherwise,
							// call the one first available in the superclass hierarchy.
							if let existingImpl = existingImpl {
								impl = existingImpl
							} else {
								let superclass: AnyClass = class_getSuperclass(objcClass)!
								impl = class_getMethodImplementation(superclass, deallocSelector)!
							}

							typealias Impl = @convention(c) (UnsafeRawPointer, Selector) -> Void
							unsafeBitCast(impl, to: Impl.self)(objectRef, deallocSelector)
						}

						let newImpl =  imp_implementationWithBlock(newImplBlock as Any)

						if !class_addMethod(objcClass, deallocSelector, newImpl, "v@:") {
							// The class has an existing `dealloc`. Preserve that as `existingImpl`.
							let deallocMethod = class_getInstanceMethod(objcClass, deallocSelector)!

							// Store the existing implementation to `existingImpl` to ensure it is
							// available before our version is swapped in.
							existingImpl = method_getImplementation(deallocMethod)

							// Store the swapped-out implementation to `existingImpl` in case
							// the implementation has been changed concurrently.
							existingImpl = method_setImplementation(deallocMethod, newImpl)
						}
					}
				}

				object.associations.setValue(token, forKey: Keys.lifetimeToken)
				object.associations.setValue(lifetime, forKey: Keys.lifetime)

				return lifetime
			} else {
				let associations = Associations(object)

				if let lifetime = associations.value(forKey: Keys.lifetime) {
					return lifetime
				}

				let (lifetime, token) = Lifetime.make()

				associations.setValue(token, forKey: Keys.lifetimeToken)
				associations.setValue(lifetime, forKey: Keys.lifetime)

				return lifetime
			}
		}
	}
}

extension Reactive where Base: AnyObject {
	/// Returns a lifetime that ends when the object is deallocated.
	@nonobjc public var lifetime: Lifetime {
		return .of(base)
	}
}
