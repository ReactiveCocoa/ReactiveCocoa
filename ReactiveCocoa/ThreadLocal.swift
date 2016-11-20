internal final class ThreadLocal<Object: AnyObject> {
	private let key: pthread_key_t
	private let initializer: () -> Object

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
