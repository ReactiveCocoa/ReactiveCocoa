import Foundation
import ReactiveSwift

private var lifetimeKey: UInt8 = 0
private var lifetimeTokenKey: UInt8 = 0

extension Reactivity where Reactant: NSObject {
	/// Returns a lifetime that ends when the receiver is deallocated.
	@nonobjc public var lifetime: Lifetime {
		objc_sync_enter(reactant)
		defer { objc_sync_exit(reactant) }

		if let lifetime = objc_getAssociatedObject(reactant, &lifetimeKey) as! Lifetime? {
			return lifetime
		}

		let token = Lifetime.Token()
		let lifetime = Lifetime(token)

		objc_setAssociatedObject(reactant, &lifetimeTokenKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		objc_setAssociatedObject(reactant, &lifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		return lifetime
	}
}
