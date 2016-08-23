import Foundation
import enum Result.NoError

/// Represents the lifetime of an object, and provides a hook to observe when
/// the object deinitializes.
public final class Lifetime {
	/// A signal that sends a Completed event when the lifetime ends.
	public let ended: Signal<(), NoError>

	/// Initialize a `Lifetime` from a lifetime token, which is expected to be
	/// associated with an object.
	///
	/// - important: The resulting lifetime object does not retain the lifetime
	///              token.
	///
	/// - parameters:
	///   - token: A lifetime token for detecting the deinitialization of the
	///            associated object.
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
		fileprivate let ended: Signal<(), NoError>

		private let endedObserver: Signal<(), NoError>.Observer

		public init() {
			(ended, endedObserver) = Signal.pipe()
		}

		deinit {
			endedObserver.sendCompleted()
		}
	}
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

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

#endif
