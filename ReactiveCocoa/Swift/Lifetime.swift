import enum Result.NoError

/// Provides a signal that completes when the lifetime object is deinitialized.
///
/// When assigned to a property of another object, provides a hook to
/// observe when that object goes out of scope.
public final class Lifetime {
	/// A signal that sends a Completed event when the lifetime ends.
	public let ended: Signal<(), NoError>

	private let endedObserver: Signal<(), NoError>.Observer

	public init() {
		(ended, endedObserver) = Signal.pipe()
	}

	deinit {
		endedObserver.sendCompleted()
	}
}

private var lifetimeKey: UInt8 = 0

extension NSObject {
	/// Returns a lifetime that ends when the receiver is deallocated.
	@nonobjc public var rac_lifetime: Lifetime {
		if let lifetime = objc_getAssociatedObject(self, &lifetimeKey) as! Lifetime? {
			return lifetime
		}

		let lifetime = Lifetime()
		objc_setAssociatedObject(self, &lifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		return lifetime
	}
}
