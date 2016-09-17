import Foundation
import ReactiveSwift

private var lifetimeKey: UInt8 = 0
private var lifetimeTokenKey: UInt8 = 0

extension NSObject {
	/// Returns a lifetime that ends when the receiver is deallocated.
	@nonobjc public var rac_lifetime: Lifetime {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		if let lifetime = objc_getAssociatedObject(self, &lifetimeKey) as! Lifetime? {
			return lifetime
		}

		let token = Lifetime.Token()
		let lifetime = Lifetime(token)

		objc_setAssociatedObject(self, &lifetimeTokenKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		objc_setAssociatedObject(self, &lifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		return lifetime
	}
}
