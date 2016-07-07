import enum Result.NoError

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

// MARK: Removed Types and APIs in ReactiveCocoa 5.0.

// Renamed Protocols
@available(*, unavailable, renamed:"ActionProtocol")
public enum ActionType {}

@available(*, unavailable, renamed:"SignalProtocol")
public enum SignalType {}

@available(*, unavailable, renamed:"SignalProducerProtocol")
public enum SignalProducerType {}

@available(*, unavailable, renamed:"PropertyProtocol")
public enum PropertyType {}

@available(*, unavailable, renamed:"MutablePropertyProtocol")
public enum MutablePropertyType {}

@available(*, unavailable, renamed:"ObserverProtocol")
public enum ObserverType {}

@available(*, unavailable, renamed:"SchedulerProtocol")
public enum SchedulerType {}

@available(*, unavailable, renamed:"DateSchedulerProtocol")
public enum DateSchedulerType {}

@available(*, unavailable, renamed:"OptionalProtocol")
public enum OptionalType {}

@available(*, unavailable, renamed:"EventLoggerProtocol")
public enum EventLoggerType {}

@available(*, unavailable, renamed:"EventProtocol")
public enum EventType {}

// Renamed Properties

extension Disposable {
	@available(*, unavailable, renamed:"isDisposed")
	public var disposed: Bool { fatalError() }
}

extension ActionProtocol {
	@available(*, unavailable, renamed:"isEnabled")
	public var enabled: Bool { fatalError() }

	@available(*, unavailable, renamed:"isExecuting")
	public var executing: Bool { fatalError() }
}

extension CocoaAction {
	@available(*, unavailable, renamed:"isEnabled")
	@nonobjc public var enabled: Bool { fatalError() }

	@available(*, unavailable, renamed:"isExecuting")
	@nonobjc public var executing: Bool { fatalError() }
}

// Renamed Enum cases

extension Event {
	@available(*, unavailable, renamed:"next")
	public static var Next: Event<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"failed")
	public static var Failed: Event<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"completed")
	public static var Completed: Event<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"interrupted")
	public static var Interrupted: Event<Value, Error> { fatalError() }
}

extension ActionError {
	@available(*, unavailable, renamed:"producerFailed")
	public static var ProducerError: ActionError { fatalError() }

	@available(*, unavailable, renamed:"disabled")
	public static var NotEnabled: ActionError { fatalError() }
}

extension FlattenStrategy {
	@available(*, unavailable, renamed:"latest")
	public static var Latest: FlattenStrategy { fatalError() }

	@available(*, unavailable, renamed:"concat")
	public static var Concat: FlattenStrategy { fatalError() }

	@available(*, unavailable, renamed:"merge")
	public static var Merge: FlattenStrategy { fatalError() }
}

// Methods

extension Bag {
	@available(*, unavailable, renamed:"remove(using:)")
	public func removeValueForToken(_ token: RemovalToken) { fatalError() }
}

extension CompositeDisposable {
	@available(*, unavailable, renamed:"add(_:)")
	public func addDisposable(_ d: Disposable) -> DisposableHandle { fatalError() }
}

extension SignalProtocol {
	@available(*, unavailable, renamed:"takeFirst(_:)")
	public func take(_ count: Int) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skipFirst(_:)")
	public func skip(_ count: Int) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"observe(on:)")
	public func observeOn(_ scheduler: UIScheduler) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"combineLatest(with:)")
	public func combineLatestWith<S: SignalProtocol>(_ otherSignal: S) -> Signal<(Value, S.Value), Error> { fatalError() }

	@available(*, unavailable, renamed:"zip(with:)")
	public func zipWith<S: SignalProtocol>(_ otherSignal: S) -> Signal<(Value, S.Value), Error> { fatalError() }

	@available(*, unavailable, renamed:"take(until:)")
	public func takeUntil(_ trigger: Signal<(), NoError>) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"take(untilReplacement:)")
	public func takeUntilReplacement(_ replacement: Signal<Value, Error>) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skip(until:)")
	public func skipUntil(_ trigger: Signal<(), NoError>) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skip(while:)")
	public func skipWhile(_ predicate: (Value) -> Bool) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"take(while:)")
	public func takeWhile(_ predicate: (Value) -> Bool) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"timeout(after:raising:on:)")
	public func timeoutWithError(_ error: Error, afterInterval: TimeInterval, onScheduler: SchedulerProtocol) -> Signal<Value, Error> { fatalError() }

	@available(*, unavailable, message: "This Signal may emit errors which must be handled explicitly, or observed using `observeResult(_:)`")
	public func observeNext(next: (Value) -> Void) -> Disposable? { fatalError() }
}

extension SignalProducerProtocol {
	@available(*, unavailable, renamed:"takeFirst(_:)")
	public func take(_ count: Int) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skipFirst(_:)")
	public func skip(_ count: Int) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"observe(on:)")
	public func observeOn(_ scheduler: UIScheduler) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"start(on:)")
	public func startOn(_ scheduler: UIScheduler) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"combineLatest(with:)")
	public func combineLatestWith<U>(_ otherProducer: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> { fatalError() }

	@available(*, unavailable, renamed:"combineLatest(with:)")
	public func combineLatestWith<U>(_ otherSignal: Signal<U, Error>) -> SignalProducer<(Value, U), Error> { fatalError() }

	@available(*, unavailable, renamed:"zip(with:)")
	public func zipWith<U>(_ otherProducer: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> { fatalError() }

	@available(*, unavailable, renamed:"zip(with:)")
	public func zipWith<U>(_ otherSignal: Signal<U, Error>) -> SignalProducer<(Value, U), Error> { fatalError() }

	@available(*, unavailable, renamed:"take(until:)")
	public func takeUntil(_ trigger: Signal<(), NoError>) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"take(until:)")
	public func takeUntil(_ trigger: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"take(untilReplacement:)")
	public func takeUntilReplacement(_ replacement: Signal<Value, Error>) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"take(untilReplacement:)")
	public func takeUntilReplacement(_ replacement: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skip(until:)")
	public func skipUntil(_ trigger: Signal<(), NoError>) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skip(until:)")
	public func skipUntil(_ trigger: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"skip(while:)")
	public func skipWhile(_ predicate: (Value) -> Bool) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"take(while:)")
	public func takeWhile(_ predicate: (Value) -> Bool) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, renamed:"timeout(after:raising:on:)")
	public func timeoutWithError(_ error: Error, afterInterval: TimeInterval, onScheduler: SchedulerProtocol) -> SignalProducer<Value, Error> { fatalError() }

	@available(*, unavailable, message:"This SignalProducer may emit errors which must be handled explicitly, or observed using `startWithResult(_:)`.")
	public func startWithNext(next: (Value) -> Void) -> Disposable { fatalError() }
}

extension SignalProducer {
	@available(*, unavailable, message:"Use properties instead. `buffer(_:)` is removed in RAC 5.0.")
	public static func buffer(capacity: Int) -> (SignalProducer, Signal<Value, Error>.Observer) { fatalError() }
}

extension PropertyProtocol {
	@available(*, unavailable, renamed:"combineLatest(with:)")
	public func combineLatestWith<P: PropertyProtocol>(_ otherProperty: P) -> AnyProperty<(Value, P.Value)> { fatalError() }

	@available(*, unavailable, renamed:"zip(with:)")
	public func zipWith<P: PropertyProtocol>(_ otherProperty: P) -> AnyProperty<(Value, P.Value)> { fatalError() }
}
