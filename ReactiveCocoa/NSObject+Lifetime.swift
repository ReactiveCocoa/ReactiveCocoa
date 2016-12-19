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

			objc_setAssociatedObject(base, &lifetimeTokenKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			objc_setAssociatedObject(base, &lifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

			return lifetime
		}
	}
}
