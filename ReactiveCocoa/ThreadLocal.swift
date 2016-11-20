/// A lazily-initialized container that maintains thread-specific instances of
/// `Object`.
///
/// When being accessed via `local`, if no existing instance of `Object` is
/// found in the container for the current thread, it creates an instance using
/// the supplied initializer.
internal final class ThreadLocal<Object: AnyObject> {
	private let key: pthread_key_t
	private let initializer: () -> Object

	/// The instance of `Object` specific to the current thread.
	var local: Object {
		get {
			if let pointer = pthread_getspecific(key) {
				return Unmanaged.fromOpaque(pointer).takeUnretainedValue()
			} else {
				let object = initializer()
				pthread_setspecific(key, Unmanaged.passRetained(object).toOpaque())
				return object
			}
		}
	}

	/// Initialize a container that maintains thread-specific instances of
	/// `Object`.
	///
	/// - parameters:
	///   - initializer: The closure that creates an instance of `Object`.
	init(initializer: @escaping () -> Object) {
		var key = pthread_key_t()
		let status = pthread_key_create(&key) { pointer in
			Unmanaged<AnyObject>.fromOpaque(pointer).release()
		}
		precondition(status == 0)

		self.key = key
		self.initializer = initializer
	}
}
