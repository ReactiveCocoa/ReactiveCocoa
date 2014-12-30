/// A SignalProducer creates Signals that can produce values of type T.
///
/// SignalProducers can be used to represent operations or tasks, like network
/// requests, where each invocation of start() will create a new underlying
/// operation. This ensures that consumers will receive the results, versus a
/// plain Signal, where the results might be sent before any observers are
/// attached.
///
/// Because of the behavior of start(), different Signals created from the
/// producer may see a different version of Events. The Events may arrive in a
/// different order between Signals, or the stream might be completely
/// different!
public struct SignalProducer<T> {
	/// Initializes a SignalProducer that will invoke the given closure once
	/// for each invocation of start().
	///
	/// The events that the closure puts into the given sink will become the
	/// events sent by the started Signal to its observers.
	///
	/// If the Disposable returned from start() is disposed, the given
	/// CompositeDisposable will be disposed as well, at which point work should
	/// be cancelled, and any temporary resources cleaned up. The
	/// CompositeDisposable will also be disposed when an `Error` or `Completed`
	/// event is sent to the sink.
	public init(_ startHandler: (SinkOf<Event<T>>, CompositeDisposable) -> ())

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete.
	public init(value: T)

	/// Creates a producer for a Signal that will immediately send an error.
	public init(error: NSError)

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete, or immediately send an error, depending on the given
	/// Result.
	public init(result: Result<T>)

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	public init<S: SequenceType where S.Generator.Element == T>(values: S)

	/// A producer for a Signal that will immediately complete without sending
	/// any values.
	public static let empty: SignalProducer

	/// A producer for a Signal that will never send any events.
	public static let never: SignalProducer

	/// Creates a buffer for Events, with the given capacity, and a SignalProducer for
	/// a signal that will send Events from the buffer.
	///
	/// When events are put into the returned sink, they will be added to the
	/// buffer. If the buffer is already at capacity, the earliest (oldest)
	/// event will be dropped to make room for the new event.
	///
	/// Signals created from the returned producer will stay alive until an
	/// `Error` or `Completed` is added to the buffer. If the buffer does not
	/// contain such an event when the Signal is started, all events sent to the
	/// returned sink will be automatically forwarded to the Signal’s observers
	/// until a terminating event is received.
	///
	/// After an `Error` or `Completed` event has been added to the buffer, the
	/// sink will not add any further events.
	public static func buffer(capacity: Int) -> (SignalProducer, SinkOf<Event<T>>)

	public static func try(operation: () -> Result<T>) -> SignalProducer
	public static func try(operation: NSErrorPointer -> T?) -> SignalProducer

	/// Creates a Signal from the producer, passes it into the given closure,
	/// then starts sending events on the Signal when the closure has returned.
	///
	/// If the closure returns a non-nil Disposable, it will be automatically
	/// disposed when an `Error` or `Completed` event is sent, or when the
	/// disposable returned from start() has been disposed.
	///
	/// Returns a Disposable which can be used to cancel the work associated
	/// with the Signal, and prevent any future events from being sent.
	public func start(setUp: Signal<T> -> Disposable?) -> Disposable

	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callbacks when events are
	/// received.
	///
	/// Returns a Disposable which can be used to cancel the work associated
	/// with the Signal, and prevent any future callbacks from being invoked.
	public func start(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable

	/// Lifts a Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new SignalProducer which will apply
	/// the given Signal operator to _every_ created Signal, just as if the
	/// operator had been applied to each Signal yielded from start().
	public func lift<U>(transform: Signal<T> -> Signal<U>) -> SignalProducer<U>
}

/// Applies a Signal operator to a SignalProducer (equivalent to
/// SignalProducer.lift).
///
/// This will create a new SignalProducer which will apply the given Signal
/// operator to _every_ created Signal, just as if the operator had been applied
/// to each Signal yielded from start().
///
/// Example:
///
/// 	let filteredProducer = intProducer |> filter { num in num % 2 == 0 }
public func |> <T, U>(producer: SignalProducer<T>, transform: Signal<T> -> Signal<U>) -> SignalProducer<U>

/// Applies a SignalProducer operator to a SignalProducer.
///
/// Example:
///
/// 	filteredProducer
/// 	|> startOn(MainScheduler())
/// 	|> start { signal in
/// 		signal.observe(next: { num in println(num) })
/// 	}
public func |> <T, U>(producer: SignalProducer<T>, transform: SignalProducer<T> -> U) -> U

public func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> SignalProducer<NSDate>
public func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval) -> SignalProducer<NSDate>

public func concat<T>(producer: SignalProducer<SignalProducer<T>>) -> SignalProducer<T>
public func concatMap<T, U>(transform: T -> SignalProducer<U>)(producer: SignalProducer<T>) -> SignalProducer<U>
public func merge<T>(producer: SignalProducer<SignalProducer<T>>) -> SignalProducer<T>
public func mergeMap<T, U>(transform: T -> SignalProducer<U>)(producer: SignalProducer<T>) -> SignalProducer<U>
public func switchMap<T, U>(transform: T -> SignalProducer<U>)(producer: SignalProducer<T>) -> SignalProducer<U>
public func switchToLatest<T>(producer: SignalProducer<SignalProducer<T>>) -> SignalProducer<T>

public func catch<T>(handler: NSError -> SignalProducer<T>)(producer: SignalProducer<T>) -> SignalProducer<T>
public func combineLatestWith<T, U>(otherSignalProducer: SignalProducer<U>)(producer: SignalProducer<T>) -> SignalProducer<(T, U)>
public func concat<T>(next: SignalProducer<T>)(producer: SignalProducer<T>) -> SignalProducer<T>
public func on<T>(started: () -> () = doNothing, event: Event<T> -> () = doNothing, next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing, terminated: () -> () = doNothing, disposed: () -> () = doNothing)(producer: SignalProducer<T>) -> SignalProducer<T>
public func repeat<T>(count: Int)(producer: SignalProducer<T>) -> SignalProducer<T>
public func retry<T>(count: Int)(producer: SignalProducer<T>) -> SignalProducer<T>
public func startOn<T>(scheduler: Scheduler)(producer: SignalProducer<T>) -> SignalProducer<T>
public func takeUntil<T>(trigger: SignalProducer<()>)(producer: SignalProducer<T>) -> SignalProducer<T>
public func takeUntilReplacement<T>(replacement: SignalProducer<T>)(producer: SignalProducer<T>) -> SignalProducer<T>
public func then<T, U>(replacement: SignalProducer<U>)(producer: SignalProducer<T>) -> SignalProducer<U>
public func zipWith<T, U>(otherSignalProducer: SignalProducer<U>)(producer: SignalProducer<T>) -> SignalProducer<(T, U)>
