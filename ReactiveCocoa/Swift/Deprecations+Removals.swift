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
