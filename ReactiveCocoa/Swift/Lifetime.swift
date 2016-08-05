import enum Result.NoError

/// Represent the lifetime of an object, and provide a hook to observe when the
/// object deinitializes.
public final class Lifetime {
	/// A signal that sends a Completed event when the lifetime ends.
	public let ended: Signal<(), NoError>

	public init(_ token: Token) {
		ended = token.ended
	}

	/// A token object which completes its signal when it deinitializes.
	///
	/// It is generally used in conjuncion with `Lifetime` as a private
	/// deinitialization trigger.
	///
	/// ```
	/// class MyController {
	///		private let token = Lifetime.Token()
	///		public var lifetime: Lifetime {
	///			return Lifetime(token)
	///		}
	/// }
	/// ```
	public final class Token {
		/// A signal that sends a Completed event when the lifetime ends.
		private let ended: Signal<(), NoError>

		private let endedObserver: Signal<(), NoError>.Observer

		public init() {
			(ended, endedObserver) = Signal.pipe()
		}

		deinit {
			endedObserver.sendCompleted()
		}
	}
}

private var lifetimeKey: UInt8 = 0

extension NSObject {
	/// Returns a lifetime that ends when the receiver is deallocated.
	@nonobjc public var rac_lifetime: Lifetime {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		if let token = objc_getAssociatedObject(self, &lifetimeKey) as! Lifetime.Token? {
			return Lifetime(token)
		}

		let token = Lifetime.Token()
		objc_setAssociatedObject(self, &lifetimeKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		return Lifetime(token)
	}
}
