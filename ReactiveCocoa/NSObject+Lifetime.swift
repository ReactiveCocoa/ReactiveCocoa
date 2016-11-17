import Foundation
import ReactiveSwift

private var lifetimeKey: UInt8 = 0
private var lifetimeTokenKey: UInt8 = 0

extension Reactive where Base: NSObject {
	/// Returns a lifetime that ends when the object is deallocated.
	@nonobjc public var lifetime: Lifetime {
		return base.synchronized {
			if let lifetime = base.value(forAssociatedKey: &lifetimeKey) as! Lifetime? {
				return lifetime
			}

			let token = Lifetime.Token()
			let lifetime = Lifetime(token)

			base.setValue(token, forAssociatedKey: &lifetimeTokenKey)
			base.setValue(lifetime, forAssociatedKey: &lifetimeKey)

			return lifetime
		}
	}
}
