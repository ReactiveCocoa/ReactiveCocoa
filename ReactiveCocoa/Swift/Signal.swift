/// A push-driven stream that sends Events over time.
///
/// An observer of a Signal will see the exact same sequence of events as all
/// other observers. In other words, events will be sent to all observers at the
/// same time.
///
/// Signals are generally used to represent event streams that are already “in
/// progress,” like notifications, user input, etc. To represent streams that
/// must first be _started_, see the SignalProducer type.
///
/// Signals do not need to be retained. A Signal will be automatically kept
/// alive until the event stream has terminated, or until the operation which
/// yielded the Signal (e.g., SignalProducer.start) has been cancelled.
public final class Signal<T> {
	public typealias Observer = SinkOf<Event<T>>

	private let lock = NSRecursiveLock()
	private let disposable = CompositeDisposable()
	private var observers: Bag<Observer>? = Bag()

	/// Initializes a Signal that will immediately invoke the given generator,
	/// then forward events put into the given sink.
	///
	/// The Signal will remain alive until an `Error` or `Completed` event is
	/// sent, or until the given Disposable has been disposed.
	public init(_ generator: (Observer, CompositeDisposable) -> ()) {
		lock.name = "org.reactivecocoa.ReactiveCocoa.Signal"

		let sink = Observer { event in
			self.lock.lock()

			if let observers = self.observers {
				for sink in observers {
					sink.put(event)
				}
			}

			if event.isTerminating {
				self.observers = nil
			}

			self.lock.unlock()
		}

		generator(sink, disposable)
	}

	deinit {
		disposable.dispose()
	}

	/// A Signal that never sends any events.
	public class var never: Signal {
		return self { _ in () }
	}

	/// Creates a Signal that will be controlled by sending events to the given
	/// observer (sink).
	///
	/// The Signal will remain alive until an `Error` or `Completed` event is
	/// sent to the observer.
	public class func pipe() -> (Signal, Observer) {
		var sink: Observer?
		let signal = self { innerSink, disposable in
			sink = innerSink
		}

		return (signal, sink!)
	}

	/// Observes the Signal by sending any future events to the given sink. If
	/// the Signal has already terminated, the sink will not receive any events.
	///
	/// Returns a Disposable which can be used to disconnect the sink. Disposing
	/// of the Disposable will have no effect on the Signal itself.
	public func observe<S: SinkType where S.Element == Event<T>>(observer: S) -> Disposable {
		let sink = Observer(observer)

		lock.lock()
		let token = self.observers?.insert(sink)
		lock.unlock()

		return ActionDisposable {
			if let token = token {
				self.lock.lock()
				self.observers?.removeValueForToken(token)
				self.lock.unlock()
			}
		}
	}

	/// Observes the Signal by invoking the given callbacks when events are
	/// received. If the Signal has already terminated, none of the specified
	/// callbacks will be invoked.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callbacks. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observe(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable {
		return observe(Event.sink(next: next, error: error, completed: completed))
	}
}

infix operator |> {
	associativity left

	// Bind tighter than assignment, but looser than everything else.
	precedence 95
}

/// Applies a Signal operator to a Signal.
///
/// Example:
///
/// 	intSignal
/// 	|> filter { num in num % 2 == 0 }
/// 	|> map(toString)
/// 	|> observe(next: { string in println(string) })
public func |> <T, U>(signal: Signal<T>, transform: Signal<T> -> U) -> U {
	return transform(signal)
}

/*
public func combineLatestWith<T, U>(otherSignal: Signal<U>)(signal: Signal<T>) -> Signal<(T, U)>
public func combinePrevious<T>(initial: T)(signal: Signal<T>) -> Signal<(T, T)>
public func concat<T>(next: Signal<T>)(signal: Signal<T>) -> Signal<T>
public func delay<T>(interval: NSTimeInterval, onScheduler scheduler: DateScheduler)(signal: Signal<T>) -> Signal<T>
public func dematerialize<T>(signal: Signal<Event<T>>) -> Signal<T>
public func filter<T>(predicate: T -> Bool)(signal: Signal<T>) -> Signal<T>
public func map<T, U>(transform: T -> U)(signal: Signal<T>) -> Signal<U>
public func mapAccumulate<State, T, U>(initialState: State, _ transform: (State, T) -> (State?, U))(signal: Signal<T>) -> Signal<U> {
public func materialize<T>(signal: Signal<T>) -> Signal<Event<T>>
public func observeOn<T>(scheduler: Scheduler)(signal: Signal<T>) -> Signal<T>
public func reduce<T, U>(initial: U, combine: (U, T) -> U)(signal: Signal<T>) -> Signal<U>
public func sampleOn<T>(sampler: Signal<()>)(signal: Signal<T>) -> Signal<T>
public func scan<T, U>(initial: U, combine: (U, T) -> U)(signal: Signal<T>) -> Signal<U>
public func skip<T>(count: Int)(signal: Signal<T>) -> Signal<T>
public func skipRepeats<T: Equatable>(signal: Signal<T>) -> Signal<T>
public func skipRepeats<T>(isRepeat: (T, T) -> Bool)(signal: Signal<T>) -> Signal<T>
public func skipWhile<T>(predicate: T -> Bool)(signal: Signal<T>) -> Signal<T>
public func take<T>(count: Int)(signal: Signal<T>) -> Signal<T>
public func takeLast<T>(count: Int)(signal: Signal<T>) -> Signal<T>
public func takeUntil<T>(trigger: Signal<()>)(signal: Signal<T>) -> Signal<T>
public func takeUntilReplacement<T>(replacement: Signal<T>)(signal: Signal<T>) -> Signal<T>
public func takeWhile<T>(predicate: T -> Bool)(signal: Signal<T>) -> Signal<T>
public func throttle<T>(interval: NSTimeInterval, onScheduler scheduler: DateScheduler)(signal: Signal<T>) -> Signal<T>
public func timeoutWithError<T>(error: NSError, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateScheduler)(signal: Signal<T>) -> Signal<T>
public func try<T>(operation: (T, NSErrorPointer) -> Bool)(signal: Signal<T>) -> Signal<T>
public func try<T>(operation: T -> Result<()>)(signal: Signal<T>) -> Signal<T>
public func tryMap<T, U>(operation: (T, NSErrorPointer) -> U?)(signal: Signal<T>) -> Signal<U>
public func tryMap<T, U>(operation: T -> Result<U>)(signal: Signal<T>) -> Signal<U>
public func zipWith<T, U>(otherSignal: Signal<U>)(signal: Signal<T>) -> Signal<(T, U)>
*/

/// Signal.observe() as a free function, for easier use with |>.
public func observe<T, S: SinkType where S.Element == Event<T>>(sink: S)(signal: Signal<T>) -> Disposable {
	return signal.observe(sink)
}

/// Signal.observe() as a free function, for easier use with |>.
public func observe<T>(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing)(signal: Signal<T>) -> Disposable {
	return signal.observe(next: next, error: error, completed: completed)
}
