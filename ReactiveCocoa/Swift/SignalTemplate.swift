/// A template for creating Signals.
///
/// SignalTemplates can be used to represent operations or tasks, like network
/// requests, where each invocation of start() will create a new underlying
/// operation. This ensures that consumers will receive the results, versus a
/// plain Signal, where the results might be sent before any observers are
/// attached.
///
/// Because of the behavior of start(), different Signals created from the
/// template may see a different version of Events. The Events may arrive in a
/// different order between Signals, or the stream might be completely
/// different!
public struct SignalTemplate<T> {
	/// Initializes a SignalTemplate that will invoke the given closure once
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

	/// Creates a template for a Signal that will immediately send one value
	/// then complete.
	public init(value: T)

	/// Creates a template for a Signal that will immediately send an error.
	public init(error: NSError)

	/// Creates a template for a Signal that will immediately send one value
	/// then complete, or immediately send an error, depending on the given
	/// Result.
	public init(result: Result<T>)

	/// Creates a template for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	public init<S: SequenceType where S.Generator.Element == T>(values: S)

	/// A template for a Signal that will immediately complete without sending
	/// any values.
	public static let empty: SignalTemplate

	/// A template for a Signal that will never send any events.
	public static let never: SignalTemplate

	/// Creates a buffer for Events, with the given capacity, and a template for
	/// a signal that will send Events from the buffer.
	///
	/// When events are put into the returned sink, they will be added to the
	/// buffer. If the buffer is already at capacity, the earliest (oldest)
	/// event will be dropped to make room for the new event.
	///
	/// Signals created from the returned template will stay alive until an
	/// `Error` or `Completed` is added to the buffer. If the buffer does not
	/// contain such an event when the Signal is started, all events sent to the
	/// returned sink will be automatically forwarded to the Signal’s observers
	/// until a terminating event is received.
	///
	/// After an `Error` or `Completed` event has been added to the buffer, the
	/// sink will not add any further events.
	public static func buffer(capacity: Int) -> (SignalTemplate, SinkOf<Event<T>>)

	public static func try(operation: () -> Result<T>) -> SignalTemplate
	public static func try(operation: NSErrorPointer -> T?) -> SignalTemplate

	/// Creates a Signal from the template, passes it into the given closure,
	/// then starts sending events on the Signal when the closure has returned.
	///
	/// If the closure returns a non-nil Disposable, it will be automatically
	/// disposed when an `Error` or `Completed` event is sent, or when the
	/// disposable returned from start() has been disposed.
	///
	/// Returns a Disposable which can be used to cancel the work associated
	/// with the Signal, and prevent any future events from being sent.
	public func start(setUp: Signal<T> -> Disposable?) -> Disposable

	/// Creates a Signal from the template, then adds exactly one observer to
	/// the Signal, which will invoke the given callbacks when events are
	/// received.
	///
	/// Returns a Disposable which can be used to cancel the work associated
	/// with the Signal, and prevent any future callbacks from being invoked.
	public func start(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable

	/// Lifts a Signal operator to operate upon SignalTemplates instead.
	///
	/// In other words, this will create a new SignalTemplate which will apply
	/// the given Signal operator to _every_ created Signal, just as if the
	/// operator had been applied to each Signal yielded from start().
	public func lift<U>(transform: Signal<T> -> Signal<U>) -> SignalTemplate<U>
}

/// Applies a Signal operator to a SignalTemplate (equivalent to
/// SignalTemplate.lift).
///
/// This will create a new SignalTemplate which will apply the given Signal
/// operator to _every_ created Signal, just as if the operator had been applied
/// to each Signal yielded from start().
///
/// Example:
///
/// 	let filteredTemplate = intTemplate |> filter { num in num % 2 == 0 }
public func |> <T, U>(template: SignalTemplate<T>, transform: Signal<T> -> Signal<U>) -> SignalTemplate<U>

/// Applies a SignalTemplate operator to a SignalTemplate.
///
/// Example:
///
/// 	filteredTemplate
/// 	|> startOn(MainScheduler())
/// 	|> start { signal in
/// 		signal.observe(next: { num in println(num) })
/// 	}
public func |> <T, U>(template: SignalTemplate<T>, transform: SignalTemplate<T> -> U) -> U

public func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> SignalTemplate<NSDate>
public func timer(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval) -> SignalTemplate<NSDate>

public func concat<T>(template: SignalTemplate<SignalTemplate<T>>) -> SignalTemplate<T>
public func concatMap<T, U>(transform: T -> SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
public func merge<T>(template: SignalTemplate<SignalTemplate<T>>) -> SignalTemplate<T>
public func mergeMap<T, U>(transform: T -> SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
public func switchMap<T, U>(transform: T -> SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
public func switchToLatest<T>(template: SignalTemplate<SignalTemplate<T>>) -> SignalTemplate<T>

public func catch<T>(handler: NSError -> SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func combineLatestWith<T, U>(otherTemplate: SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<(T, U)>
public func concat<T>(next: SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func on<T>(started: () -> () = doNothing, event: Event<T> -> () = doNothing, next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing, terminated: () -> () = doNothing, disposed: () -> () = doNothing)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func repeat<T>(count: Int)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func retry<T>(count: Int)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func startOn<T>(scheduler: Scheduler)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func takeUntil<T>(trigger: SignalTemplate<()>)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func takeUntilReplacement<T>(replacement: SignalTemplate<T>)(template: SignalTemplate<T>) -> SignalTemplate<T>
public func then<T, U>(replacement: SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<U>
public func zipWith<T, U>(otherTemplate: SignalTemplate<U>)(template: SignalTemplate<T>) -> SignalTemplate<(T, U)>
