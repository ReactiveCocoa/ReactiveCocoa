import enum Result.NoError

/// Describes the ability of an object to notify others of its deinitialization.
/// Proxy objects may pass through the lifetime of its underlying object.
public protocol LifetimeProviding: class {
	/// A signal representing the lifetime of `self`.
	///
	/// The signal emits `completed` when the object completes, or
	/// `interrupted` after the object is completed.
	var lifetime: Signal<(), NoError> { get }

	/// An interruptible observation to the lifetime of `self`.
	///
	/// The signal emits `completed` when the object completes, or
	/// `interrupted` after the object is completed.
	var lifetimeProducer: SignalProducer<(), NoError> { get }
}

internal final class DeallocationToken {
	let (deallocSignal, observer) = Signal<(), NoError>.pipe()

	deinit {
		observer.sendCompleted()
	}
}
