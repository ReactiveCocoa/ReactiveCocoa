// MARK: Removed APIs in ReactiveCocoa 5.0.

extension SignalType {
	@available(*, unavailable, message="This Signal may emit errors which must be handled explicitly, or observed using observeResult:")
	public func observeNext(next: Value -> Void) -> Disposable? {
		fatalError()
	}
}

extension SignalProducer {
	@available(*, unavailable, message="Use properties instead. 'buffer' is removed in RAC 5.0")
	public static func buffer(capacity: Int) -> (SignalProducer, Signal<Value, Error>.Observer) {
		fatalError()
	}
}

extension SignalProducerType {
	@available(*, unavailable, message="This SignalProducer may emit errors which must be handled explicitly, or observed using startWithResult:")
	public func startWithNext(next: Value -> Void) -> Disposable {
		return start(Observer(next: next))
	}
}