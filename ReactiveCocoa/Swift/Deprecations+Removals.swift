// MARK: Deprecated APIs

extension QueueScheduler {
	/// - warning: Obsoleted in OS X 10.11
	@available(OSX, deprecated:10.10, obsoleted:10.11, message:"Use init(qos:, name:) instead.")
	@available(iOS, deprecated:8.0, obsoleted:9.0, message:"Use init(qos:, name:) instead.")
	public convenience init(queue: DispatchQueue, name: String = "org.reactivecocoa.ReactiveCocoa.QueueScheduler") {
		self.init(internalQueue: DispatchQueue(label: name, attributes: DispatchQueueAttributes.serial))
		self.queue.setTarget(queue: queue)
	}
}

// MARK: Removed APIs in ReactiveCocoa 5.0.

extension SignalProtocol {
	@available(*, unavailable, message: "This Signal may emit errors which must be handled explicitly, or observed using `observeResult(_:)`")
	public func observeNext(next: (Value) -> Void) -> Disposable? {
		fatalError()
	}
}

extension SignalProducer {
	@available(*, unavailable, message:"Use properties instead. `buffer(_:)` is removed in RAC 5.0.")
	public static func buffer(capacity: Int) -> (SignalProducer, Signal<Value, Error>.Observer) {
		fatalError()
	}
}

extension SignalProducerProtocol {
	@available(*, unavailable, message:"This SignalProducer may emit errors which must be handled explicitly, or observed using `startWithResult(_:)`.")
	public func startWithNext(next: (Value) -> Void) -> Disposable {
		fatalError()
	}
}
