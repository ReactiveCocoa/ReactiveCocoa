import enum Result.NoError

/// Describes the ability of an object to notify others of its deinitialization.
///
/// Proxy objects are allowed to pass through the lifetime of its underlying object.
public protocol LifetimeProviding: class {
	/// The signal emits `completed` when the object deinitializes, or
	/// `interrupted` after the object has deinitialized.
	var lifetime: Signal<(), NoError> { get }

	/// A producer of signals that would emit `completed` when the
	/// object deinitializes, or `interrupted` after the object has
	/// deinitialized.
	var lifetimeProducer: SignalProducer<(), NoError> { get }
}

extension LifetimeProviding {
	/// A producer of signals that would emit `completed` when the
	/// object deinitializes, or `interrupted` after the object has
	/// deinitialized.
	public var lifetimeProducer: SignalProducer<(), NoError> {
		return SignalProducer(signal: lifetime)
	}
}

internal final class DeallocationToken {
	let (deallocSignal, observer) = Signal<(), NoError>.pipe()

	deinit {
		observer.sendCompleted()
	}
}
