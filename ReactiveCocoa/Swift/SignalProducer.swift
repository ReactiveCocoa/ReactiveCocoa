import Result

/// A SignalProducer creates Signals that can produce values of type `Value` and/or
/// fail with errors of type `Error`. If no failure should be possible, NoError
/// can be specified for `Error`.
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
public struct SignalProducer<Value, Error: ErrorType> {
	public typealias ProducedSignal = Signal<Value, Error>

	private let startHandler: (Signal<Value, Error>.Observer, CompositeDisposable) -> ()

	/// Initializes a SignalProducer that will emit the same events as the given signal.
	///
	/// If the Disposable returned from start() is disposed or a terminating
	/// event is sent to the observer, the given signal will be
	/// disposed.
	public init<S: SignalType where S.Value == Value, S.Error == Error>(signal: S) {
		self.init { observer, disposable in
			disposable += signal.observe(observer)
		}
	}

	/// Initializes a SignalProducer that will invoke the given closure once
	/// for each invocation of start().
	///
	/// The events that the closure puts into the given observer will become
	/// the events sent by the started Signal to its observers.
	///
	/// If the Disposable returned from start() is disposed or a terminating
	/// event is sent to the observer, the given CompositeDisposable will be
	/// disposed, at which point work should be interrupted and any temporary
	/// resources cleaned up.
	public init(_ startHandler: (Signal<Value, Error>.Observer, CompositeDisposable) -> ()) {
		self.startHandler = startHandler
	}

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete.
	public init(value: Value) {
		self.init { observer, disposable in
			observer.sendNext(value)
			observer.sendCompleted()
		}
	}

	/// Creates a producer for a Signal that will immediately fail with the
	/// given error.
	public init(error: Error) {
		self.init { observer, disposable in
			observer.sendFailed(error)
		}
	}

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete, or immediately fail, depending on the given Result.
	public init(result: Result<Value, Error>) {
		switch result {
		case let .Success(value):
			self.init(value: value)

		case let .Failure(error):
			self.init(error: error)
		}
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	public init<S: SequenceType where S.Generator.Element == Value>(values: S) {
		self.init { observer, disposable in
			for value in values {
				observer.sendNext(value)

				if disposable.disposed {
					break
				}
			}

			observer.sendCompleted()
		}
	}

	/// A producer for a Signal that will immediately complete without sending
	/// any values.
	public static var empty: SignalProducer {
		return self.init { observer, disposable in
			observer.sendCompleted()
		}
	}

	/// A producer for a Signal that never sends any events to its observers.
	public static var never: SignalProducer {
		return self.init { _ in return }
	}

	/// Creates a queue for events that replays them when new signals are
	/// created from the returned producer.
	///
	/// When values are put into the returned observer (observer), they will be
	/// added to an internal buffer. If the buffer is already at capacity,
	/// the earliest (oldest) value will be dropped to make room for the new
	/// value.
	///
	/// Signals created from the returned producer will stay alive until a
	/// terminating event is added to the queue. If the queue does not contain
	/// such an event when the Signal is started, all values sent to the
	/// returned observer will be automatically forwarded to the Signal’s
	/// observers until a terminating event is received.
	///
	/// After a terminating event has been added to the queue, the observer
	/// will not add any further events. This _does not_ count against the
	/// value capacity so no buffered values will be dropped on termination.
	public static func buffer(capacity: Int = Int.max) -> (SignalProducer, Signal<Value, Error>.Observer) {
		precondition(capacity >= 0)

		// This is effectively used as a synchronous mutex, but permitting
		// limited recursive locking (see below).
		//
		// The queue is a "variable" just so we can use its address as the key
		// and the value for dispatch_queue_set_specific().
		var queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.SignalProducer.buffer", DISPATCH_QUEUE_SERIAL)
		dispatch_queue_set_specific(queue, &queue, &queue, nil)

		// Used as an atomic variable so we can remove observers without needing
		// to run on the queue.
		let state: Atomic<BufferState<Value, Error>> = Atomic(BufferState())

		let producer = self.init { observer, disposable in
			// Assigned to when replay() is invoked synchronously below.
			var token: RemovalToken?

			let replay: () -> () = {
				let originalState = state.modify { (var state) in
					token = state.observers?.insert(observer)
					return state
				}

				for value in originalState.values {
					observer.sendNext(value)
				}

				if let terminationEvent = originalState.terminationEvent {
					observer.action(terminationEvent)
				}
			}

			// Prevent other threads from sending events while we're replaying,
			// but don't deadlock if we're replaying in response to a buffer
			// event observed elsewhere.
			//
			// In other words, this permits limited signal recursion for the
			// specific case of replaying past events.
			if dispatch_get_specific(&queue) != nil {
				replay()
			} else {
				dispatch_sync(queue, replay)
			}

			if let token = token {
				disposable.addDisposable {
					state.modify { (var state) in
						state.observers?.removeValueForToken(token)
						return state
					}
				}
			}
		}

		let bufferingObserver: Signal<Value, Error>.Observer = Observer { event in
			// Send serially with respect to other senders, and never while
			// another thread is in the process of replaying.
			dispatch_sync(queue) {
				let originalState = state.modify { (var state) in
					if let value = event.value {
						state.addValue(value, upToCapacity: capacity)
					} else {
						// Disconnect all observers and prevent future
						// attachments.
						state.terminationEvent = event
						state.observers = nil
					}

					return state
				}

				if let observers = originalState.observers {
					for observer in observers {
						observer.action(event)
					}
				}
			}
		}

		return (producer, bufferingObserver)
	}

	/// Creates a SignalProducer that will attempt the given operation once for
	/// each invocation of start().
	///
	/// Upon success, the started signal will send the resulting value then
	/// complete. Upon failure, the started signal will fail with the error that
	/// occurred.
	public static func attempt(operation: () -> Result<Value, Error>) -> SignalProducer {
		return self.init { observer, disposable in
			operation().analysis(ifSuccess: { value in
				observer.sendNext(value)
				observer.sendCompleted()
				}, ifFailure: { error in
					observer.sendFailed(error)
			})
		}
	}

	/// Creates a Signal from the producer, passes it into the given closure,
	/// then starts sending events on the Signal when the closure has returned.
	///
	/// The closure will also receive a disposable which can be used to
	/// interrupt the work associated with the signal and immediately send an
	/// `Interrupted` event.
	public func startWithSignal(@noescape setUp: (Signal<Value, Error>, Disposable) -> ()) {
		let (signal, observer) = Signal<Value, Error>.pipe()

		// Disposes of the work associated with the SignalProducer and any
		// upstream producers.
		let producerDisposable = CompositeDisposable()

		// Directly disposed of when start() or startWithSignal() is disposed.
		let cancelDisposable = ActionDisposable {
			observer.sendInterrupted()
			producerDisposable.dispose()
		}

		setUp(signal, cancelDisposable)

		if cancelDisposable.disposed {
			return
		}

		let wrapperObserver: Signal<Value, Error>.Observer = Observer { event in
			observer.action(event)

			if event.isTerminating {
				// Dispose only after notifying the Signal, so disposal
				// logic is consistently the last thing to run.
				producerDisposable.dispose()
			}
		}

		startHandler(wrapperObserver, producerDisposable)
	}
}

private struct BufferState<Value, Error: ErrorType> {
	// All values in the buffer.
	var values: [Value] = []

	// Any terminating event sent to the buffer.
	//
	// This will be nil if termination has not occurred.
	var terminationEvent: Event<Value, Error>?

	// The observers currently attached to the buffered producer, or nil if the
	// producer was terminated.
	var observers: Bag<Signal<Value, Error>.Observer>? = Bag()

	// Appends a new value to the buffer, trimming it down to the given capacity
	// if necessary.
	mutating func addValue(value: Value, upToCapacity capacity: Int) {
		values.append(value)

		while values.count > capacity {
			values.removeAtIndex(0)
		}
	}
}

public protocol SignalProducerType {
	/// The type of values being sent on the producer
	typealias Value
	/// The type of error that can occur on the producer. If errors aren't possible
	/// then `NoError` can be used.
	typealias Error: ErrorType

	/// Extracts a signal producer from the receiver.
	var producer: SignalProducer<Value, Error> { get }

	/// Creates a Signal from the producer, passes it into the given closure,
	/// then starts sending events on the Signal when the closure has returned.
	func startWithSignal(@noescape setUp: (Signal<Value, Error>, Disposable) -> ())
}

extension SignalProducer: SignalProducerType {
	public var producer: SignalProducer {
		return self
	}
}

extension SignalProducerType {
	/// Creates a Signal from the producer, then attaches the given observer to
	/// the Signal as an observer.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the signal and immediately send an `Interrupted` event.
	public func start(observer: Signal<Value, Error>.Observer = Signal<Value, Error>.Observer()) -> Disposable {
		var disposable: Disposable!

		startWithSignal { signal, innerDisposable in
			signal.observe(observer)
			disposable = innerDisposable
		}

		return disposable
	}

	/// Convenience override for start(_:) to allow trailing-closure style
	/// invocations.
	public func start(observerAction: Signal<Value, Error>.Observer.Action) -> Disposable {
		return start(Observer(observerAction))
	}

	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callback when `next` events are
	/// received.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the Signal, and prevent any future callbacks from being invoked.
	public func startWithNext(next: Value -> ()) -> Disposable {
		return start(Observer(next: next))
	}

	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callback when a `completed` event is
	/// received.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the Signal.
	public func startWithCompleted(completed: () -> ()) -> Disposable {
		return start(Observer(completed: completed))
	}
	
	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callback when a `failed` event is
	/// received.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the Signal.
	public func startWithFailed(failed: Error -> ()) -> Disposable {
		return start(Observer(failed: failed))
	}
	
	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callback when an `interrupted` event is
	/// received.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the Signal.
	public func startWithInterrupted(interrupted: () -> ()) -> Disposable {
		return start(Observer(interrupted: interrupted))
	}

	/// Lifts an unary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new SignalProducer which will apply
	/// the given Signal operator to _every_ created Signal, just as if the
	/// operator had been applied to each Signal yielded from start().
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func lift<U, F>(transform: Signal<Value, Error> -> Signal<U, F>) -> SignalProducer<U, F> {
		return SignalProducer { observer, outerDisposable in
			self.startWithSignal { signal, innerDisposable in
				outerDisposable.addDisposable(innerDisposable)

				transform(signal).observe(observer)
			}
		}
	}

	/// Lifts a binary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new SignalProducer which will apply
	/// the given Signal operator to _every_ Signal created from the two
	/// producers, just as if the operator had been applied to each Signal
	/// yielded from start().
	///
	/// Note: starting the returned producer will start the receiver of the operator,
	/// which may not be adviseable for some operators.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func lift<U, F, V, G>(transform: Signal<Value, Error> -> Signal<U, F> -> Signal<V, G>) -> SignalProducer<U, F> -> SignalProducer<V, G> {
		return { otherProducer in
			return SignalProducer { observer, outerDisposable in
				self.startWithSignal { signal, disposable in
					outerDisposable.addDisposable(disposable)

					otherProducer.startWithSignal { otherSignal, otherDisposable in
						outerDisposable.addDisposable(otherDisposable)

						transform(signal)(otherSignal).observe(observer)
					}
				}
			}
		}
	}

	/// Lifts a binary Signal operator to operate upon a Signal and a SignalProducer instead.
	///
	/// In other words, this will create a new SignalProducer which will apply
	/// the given Signal operator to _every_ Signal created from the two
	/// producers, just as if the operator had been applied to each Signal
	/// yielded from start().
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func lift<U, F, V, G>(transform: Signal<Value, Error> -> Signal<U, F> -> Signal<V, G>) -> Signal<U, F> -> SignalProducer<V, G> {
		return { otherSignal in
			return SignalProducer { observer, outerDisposable in
				self.startWithSignal { signal, disposable in
					outerDisposable += disposable
					outerDisposable += transform(signal)(otherSignal).observe(observer)
				}
			}
		}
	}
	
	/// Maps each value in the producer to a new value.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func map<U>(transform: Value -> U) -> SignalProducer<U, Error> {
		return lift { $0.map(transform) }
	}

	/// Maps errors in the producer to a new error.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func mapError<F>(transform: Error -> F) -> SignalProducer<Value, F> {
		return lift { $0.mapError(transform) }
	}

	/// Preserves only the values of the producer that pass the given predicate.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func filter(predicate: Value -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.filter(predicate) }
	}

	/// Returns a producer that will yield the first `count` values from the
	/// input producer.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func take(count: Int) -> SignalProducer<Value, Error> {
		return lift { $0.take(count) }
	}

	/// Returns a signal that will yield an array of values when `signal` completes.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func collect() -> SignalProducer<[Value], Error> {
		return lift { $0.collect() }
	}

	/// Forwards all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func observeOn(scheduler: SchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.observeOn(scheduler) }
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given producer.
	///
	/// The returned producer will not send a value until both inputs have sent at
	/// least one value each. If either producer is interrupted, the returned producer
	/// will also be interrupted.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func combineLatestWith<U>(otherProducer: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> {
		return lift(Signal.combineLatestWith)(otherProducer)
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned producer will not send a value until both inputs have sent at
	/// least one value each. If either input is interrupted, the returned producer
	/// will also be interrupted.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func combineLatestWith<U>(otherSignal: Signal<U, Error>) -> SignalProducer<(Value, U), Error> {
		return lift(Signal.combineLatestWith)(otherSignal)
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Failed` and `Interrupted` events are always scheduled immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.delay(interval, onScheduler: scheduler) }
	}

	/// Returns a producer that will skip the first `count` values, then forward
	/// everything afterward.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func skip(count: Int) -> SignalProducer<Value, Error> {
		return lift { $0.skip(count) }
	}

	/// Treats all Events from the input producer as plain values, allowing them to be
	/// manipulated just like any other value.
	///
	/// In other words, this brings Events “into the monad.”
	///
	/// When a Completed or Failed event is received, the resulting producer will send
	/// the Event itself and then complete. When an Interrupted event is received,
	/// the resulting producer will send the Event itself and then interrupt.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func materialize() -> SignalProducer<Event<Value, Error>, NoError> {
		return lift { $0.materialize() }
	}

	/// Forwards the latest value from `self` whenever `sampler` sends a Next
	/// event.
	///
	/// If `sampler` fires before a value has been observed on `self`, nothing
	/// happens.
	///
	/// Returns a producer that will send values from `self`, sampled (possibly
	/// multiple times) by `sampler`, then complete once both input producers have
	/// completed, or interrupt if either input producer is interrupted.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func sampleOn(sampler: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.sampleOn)(sampler)
	}

	/// Forwards the latest value from `self` whenever `sampler` sends a Next
	/// event.
	///
	/// If `sampler` fires before a value has been observed on `self`, nothing
	/// happens.
	///
	/// Returns a producer that will send values from `self`, sampled (possibly
	/// multiple times) by `sampler`, then complete once both inputs have
	/// completed, or interrupt if either input is interrupted.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func sampleOn(sampler: Signal<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.sampleOn)(sampler)
	}

	/// Forwards events from `self` until `trigger` sends a Next or Completed
	/// event, at which point the returned producer will complete.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func takeUntil(trigger: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.takeUntil)(trigger)
	}

	/// Forwards events from `self` until `trigger` sends a Next or Completed
	/// event, at which point the returned producer will complete.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func takeUntil(trigger: Signal<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.takeUntil)(trigger)
	}

	/// Forwards events from `self` with history: values of the returned producer
	/// are a tuple whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member when `self`
	/// sends its first value.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func combinePrevious(initial: Value) -> SignalProducer<(Value, Value), Error> {
		return lift { $0.combinePrevious(initial) }
	}

	/// Like `scan`, but sends only the final value and then immediately completes.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func reduce<U>(initial: U, _ combine: (U, Value) -> U) -> SignalProducer<U, Error> {
		return lift { $0.reduce(initial, combine) }
	}

	/// Aggregates `self`'s values into a single combined value. When `self` emits
	/// its first value, `combine` is invoked with `initial` as the first argument and
	/// that emitted value as the second argument. The result is emitted from the
	/// producer returned from `scan`. That result is then passed to `combine` as the
	/// first argument when the next value is emitted, and so on.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func scan<U>(initial: U, _ combine: (U, Value) -> U) -> SignalProducer<U, Error> {
		return lift { $0.scan(initial, combine) }
	}

	/// Forwards only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func skipRepeats(isRepeat: (Value, Value) -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.skipRepeats(isRepeat) }
	}

	/// Does not forward any values from `self` until `predicate` returns false,
	/// at which point the returned signal behaves exactly like `self`.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func skipWhile(predicate: Value -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.skipWhile(predicate) }
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// Returns a producer which passes through `Next`, `Failed`, and `Interrupted`
	/// events from `self` until `replacement` sends an event, at which point the
	/// returned producer will send that event and switch to passing through events
	/// from `replacement` instead, regardless of whether `self` has sent events
	/// already.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func takeUntilReplacement(replacement: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return lift(Signal.takeUntilReplacement)(replacement)
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// Returns a producer which passes through `Next`, `Error`, and `Interrupted`
	/// events from `self` until `replacement` sends an event, at which point the
	/// returned producer will send that event and switch to passing through events
	/// from `replacement` instead, regardless of whether `self` has sent events
	/// already.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func takeUntilReplacement(replacement: Signal<Value, Error>) -> SignalProducer<Value, Error> {
		return lift(Signal.takeUntilReplacement)(replacement)
	}

	/// Waits until `self` completes and then forwards the final `count` values
	/// on the returned producer.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func takeLast(count: Int) -> SignalProducer<Value, Error> {
		return lift { $0.takeLast(count) }
	}

	/// Forwards any values from `self` until `predicate` returns false,
	/// at which point the returned producer will complete.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func takeWhile(predicate: Value -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.takeWhile(predicate) }
	}

	/// Zips elements of two producers into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input producers.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func zipWith<U>(otherProducer: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> {
		return lift(Signal.zipWith)(otherProducer)
	}

	/// Zips elements of this producer and a signal into pairs. The elements of 
	/// any Nth pair are the Nth elements of the two.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func zipWith<U>(otherSignal: Signal<U, Error>) -> SignalProducer<(Value, U), Error> {
		return lift(Signal.zipWith)(otherSignal)
	}

	/// Applies `operation` to values from `self` with `Success`ful results
	/// forwarded on the returned producer and `Failure`s sent as `Failed` events.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func attempt(operation: Value -> Result<(), Error>) -> SignalProducer<Value, Error> {
		return lift { $0.attempt(operation) }
	}

	/// Applies `operation` to values from `self` with `Success`ful results mapped
	/// on the returned producer and `Failure`s sent as `Failed` events.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func attemptMap<U>(operation: Value -> Result<U, Error>) -> SignalProducer<U, Error> {
		return lift { $0.attemptMap(operation) }
	}

	/// Throttle values sent by the receiver, so that at least `interval`
	/// seconds pass between each, then forwards them on the given scheduler.
	///
	/// If multiple values are received before the interval has elapsed, the
	/// latest value is the one that will be passed on.
	///
	/// If `self` terminates while a value is being throttled, that value
	/// will be discarded and the returned producer will terminate immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func throttle(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.throttle(interval, onScheduler: scheduler) }
	}

	/// Forwards events from `self` until `interval`. Then if producer isn't completed yet,
	/// fails with `error` on `scheduler`.
	///
	/// If the interval is 0, the timeout will be scheduled immediately. The producer
	/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func timeoutWithError(error: Error, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
		return lift { $0.timeoutWithError(error, afterInterval: interval, onScheduler: scheduler) }
	}
}

extension SignalProducerType where Value: OptionalType {
	/// Unwraps non-`nil` values and forwards them on the returned signal, `nil`
	/// values are dropped.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func ignoreNil() -> SignalProducer<Value.Wrapped, Error> {
		return lift { $0.ignoreNil() }
	}
}

extension SignalProducerType where Value: EventType, Error == NoError {
	/// The inverse of materialize(), this will translate a signal of `Event`
	/// _values_ into a signal of those events themselves.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func dematerialize() -> SignalProducer<Value.Value, Value.Error> {
		return lift { $0.dematerialize() }
	}
}

extension SignalProducerType where Error == NoError {
	/// Promotes a producer that does not generate failures into one that can.
	///
	/// This does not actually cause failers to be generated for the given producer,
	/// but makes it easier to combine with other producers that may fail; for
	/// example, with operators like `combineLatestWith`, `zipWith`, `flatten`, etc.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func promoteErrors<F: ErrorType>(_: F.Type) -> SignalProducer<Value, F> {
		return lift { $0.promoteErrors(F) }
	}
}

extension SignalProducerType where Value: Equatable {
	/// Forwards only those values from `self` which are not duplicates of the
	/// immedately preceding value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func skipRepeats() -> SignalProducer<Value, Error> {
		return lift { $0.skipRepeats() }
	}
}


/// Creates a repeating timer of the given interval, with a reasonable
/// default leeway, sending updates on the given scheduler.
///
/// This timer will never complete naturally, so all invocations of start() must
/// be disposed to avoid leaks.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func timer(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<NSDate, NoError> {
	// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
	// at least 10% of the timer interval.
	return timer(interval, onScheduler: scheduler, withLeeway: interval * 0.1)
}

/// Creates a repeating timer of the given interval, sending updates on the
/// given scheduler.
///
/// This timer will never complete naturally, so all invocations of start() must
/// be disposed to avoid leaks.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func timer(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType, withLeeway leeway: NSTimeInterval) -> SignalProducer<NSDate, NoError> {
	precondition(interval >= 0)
	precondition(leeway >= 0)

	return SignalProducer { observer, compositeDisposable in
		compositeDisposable += scheduler.scheduleAfter(scheduler.currentDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
			observer.sendNext(scheduler.currentDate)
		}
	}
}

extension SignalProducerType {
	/// Injects side effects to be performed upon the specified signal events.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func on(started started: (() -> ())? = nil, event: (Event<Value, Error> -> ())? = nil, failed: (Error -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil, terminated: (() -> ())? = nil, disposed: (() -> ())? = nil, next: (Value -> ())? = nil) -> SignalProducer<Value, Error> {
		return SignalProducer { observer, compositeDisposable in
			started?()
			_ = disposed.map(compositeDisposable.addDisposable)

			self.startWithSignal { signal, disposable in
				compositeDisposable.addDisposable(disposable)

				signal.observe { receivedEvent in
					event?(receivedEvent)

					switch receivedEvent {
					case let .Next(value):
						next?(value)

					case let .Failed(error):
						failed?(error)

					case .Completed:
						completed?()

					case .Interrupted:
						interrupted?()
					}

					if receivedEvent.isTerminating {
						terminated?()
					}

					observer.action(receivedEvent)
				}
			}
		}
	}

	/// Starts the returned signal on the given Scheduler.
	///
	/// This implies that any side effects embedded in the producer will be
	/// performed on the given scheduler as well.
	///
	/// Events may still be sent upon other schedulers—this merely affects where
	/// the `start()` method is run.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func startOn(scheduler: SchedulerType) -> SignalProducer<Value, Error> {
		return SignalProducer { observer, compositeDisposable in
			compositeDisposable += scheduler.schedule {
				self.startWithSignal { signal, signalDisposable in
					compositeDisposable.addDisposable(signalDisposable)
					signal.observe(observer)
				}
			}
		}
	}
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>) -> SignalProducer<(A, B), Error> {
	return a.combineLatestWith(b)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>) -> SignalProducer<(A, B, C), Error> {
	return combineLatest(a, b)
		.combineLatestWith(c)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>) -> SignalProducer<(A, B, C, D), Error> {
	return combineLatest(a, b, c)
		.combineLatestWith(d)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, E, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>) -> SignalProducer<(A, B, C, D, E), Error> {
	return combineLatest(a, b, c, d)
		.combineLatestWith(e)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, E, F, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>) -> SignalProducer<(A, B, C, D, E, F), Error> {
	return combineLatest(a, b, c, d, e)
		.combineLatestWith(f)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, E, F, G, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>) -> SignalProducer<(A, B, C, D, E, F, G), Error> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatestWith(g)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, E, F, G, H, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H), Error> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatestWith(h)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, E, F, G, H, I, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I), Error> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatestWith(i)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<A, B, C, D, E, F, G, H, I, J, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>, _ j: SignalProducer<J, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I, J), Error> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatestWith(j)
		.map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`. Will return an empty `SignalProducer` if the sequence is empty.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func combineLatest<S: SequenceType, Value, Error where S.Generator.Element == SignalProducer<Value, Error>>(producers: S) -> SignalProducer<[Value], Error> {
	var generator = producers.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { producer, next in
			producer.combineLatestWith(next).map { $0.0 + [$0.1] }
		}
	}
	
	return .empty
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>) -> SignalProducer<(A, B), Error> {
	return a.zipWith(b)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>) -> SignalProducer<(A, B, C), Error> {
	return zip(a, b)
		.zipWith(c)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>) -> SignalProducer<(A, B, C, D), Error> {
	return zip(a, b, c)
		.zipWith(d)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, E, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>) -> SignalProducer<(A, B, C, D, E), Error> {
	return zip(a, b, c, d)
		.zipWith(e)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, E, F, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>) -> SignalProducer<(A, B, C, D, E, F), Error> {
	return zip(a, b, c, d, e)
		.zipWith(f)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, E, F, G, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>) -> SignalProducer<(A, B, C, D, E, F, G), Error> {
	return zip(a, b, c, d, e, f)
		.zipWith(g)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, E, F, G, H, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H), Error> {
	return zip(a, b, c, d, e, f, g)
		.zipWith(h)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, E, F, G, H, I, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I), Error> {
	return zip(a, b, c, d, e, f, g, h)
		.zipWith(i)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<A, B, C, D, E, F, G, H, I, J, Error>(a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>, _ j: SignalProducer<J, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I, J), Error> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zipWith(j)
		.map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`. Will return an empty `SignalProducer` if the sequence is empty.
@warn_unused_result(message="Did you forget to call `start` on the producer?")
public func zip<S: SequenceType, Value, Error where S.Generator.Element == SignalProducer<Value, Error>>(producers: S) -> SignalProducer<[Value], Error> {
	var generator = producers.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { producer, next in
			producer.zipWith(next).map { $0.0 + [$0.1] }
		}
	}

	return .empty
}


extension SignalProducerType where Value: SignalProducerType, Error == Value.Error {
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` or an active inner producer fails, the returned
	/// producer will forward that failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return lift { (signal: Signal<Value, Error>) -> Signal<Value.Value, Error> in
			return signal.flatten(strategy)
		}
	}
}

extension SignalProducerType where Value: SignalType, Error == Value.Error {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` or an active inner signal emits an error, the returned
	/// producer will forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.lift { $0.flatten(strategy) }
	}
}


extension SignalProducerType {
	/// Maps each event from `producer` to a new producer, then flattens the
	/// resulting producers (into a single producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `producer` or any of the created producers fail, the returned
	/// producer will forward that failure immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `producer` to a new signal, then flattens the
	/// resulting signals (into a single producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `producer` or any of the created signals emit an error, the returned
	/// producer will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Catches any failure that may occur on the input producer, mapping to a new producer
	/// that starts in its place.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMapError<F>(handler: Error -> SignalProducer<Value, F>) -> SignalProducer<Value, F> {
		return SignalProducer { observer, disposable in
			let serialDisposable = SerialDisposable()
			disposable.addDisposable(serialDisposable)

			self.startWithSignal { signal, signalDisposable in
				serialDisposable.innerDisposable = signalDisposable

				signal.observe { event in
					switch event {
					case let .Next(value):
						observer.sendNext(value)
					case let .Failed(error):
						handler(error).startWithSignal { signal, signalDisposable in
							serialDisposable.innerDisposable = signalDisposable
							signal.observe(observer)
						}
					case .Completed:
						observer.sendCompleted()
					case .Interrupted:
						observer.sendInterrupted()
					}
				}
			}
		}
	}

	/// `concat`s `next` onto `self`.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func concat(next: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return SignalProducer<SignalProducer<Value, Error>, Error>(values: [self.producer, next]).flatten(.Concat)
	}
}

extension SignalProducerType {
	/// Repeats `self` a total of `count` times. Repeating `1` times results in
	/// an equivalent signal producer.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func times(count: Int) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return .empty
		} else if count == 1 {
			return producer
		}

		return SignalProducer { observer, disposable in
			let serialDisposable = SerialDisposable()
			disposable.addDisposable(serialDisposable)

			func iterate(current: Int) {
				self.startWithSignal { signal, signalDisposable in
					serialDisposable.innerDisposable = signalDisposable

					signal.observe { event in
						if case .Completed = event {
							let remainingTimes = current - 1
							if remainingTimes > 0 {
								iterate(remainingTimes)
							} else {
								observer.sendCompleted()
							}
						} else {
							observer.action(event)
						}
					}
				}
			}

			iterate(count)
		}
	}

	/// Ignores failures up to `count` times.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func retry(count: Int) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return producer
		} else {
			return flatMapError { _ in
				self.retry(count - 1)
			}
		}
	}

	/// Waits for completion of `producer`, *then* forwards all events from
	/// `replacement`. Any failure sent from `producer` is forwarded immediately, in
	/// which case `replacement` will not be started, and none of its events will be
	/// be forwarded. All values sent from `producer` are ignored.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func then<U>(replacement: SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		let relay = SignalProducer<U, Error> { observer, observerDisposable in
			self.startWithSignal { signal, signalDisposable in
				observerDisposable.addDisposable(signalDisposable)

				signal.observe { event in
					switch event {
					case let .Failed(error):
						observer.sendFailed(error)
					case .Completed:
						observer.sendCompleted()
					case .Interrupted:
						observer.sendInterrupted()
					case .Next:
						break
					}
				}
			}
		}

		return relay.concat(replacement)
	}

	/// Starts the producer, then blocks, waiting for the first value.
	@warn_unused_result(message="Did you forget to check the result?")
	public func first() -> Result<Value, Error>? {
		return take(1).single()
	}

	/// Starts the producer, then blocks, waiting for events: Next and Completed.
	/// When a single value or error is sent, the returned `Result` will represent
	/// those cases. However, when no values are sent, or when more than one value
	/// is sent, `nil` will be returned.
	@warn_unused_result(message="Did you forget to check the result?")
	public func single() -> Result<Value, Error>? {
		let semaphore = dispatch_semaphore_create(0)
		var result: Result<Value, Error>?

		take(2).start { event in
			switch event {
			case let .Next(value):
				if result != nil {
					// Move into failure state after recieving another value.
					result = nil
					return
				}
				result = .Success(value)
			case let .Failed(error):
				result = .Failure(error)
				dispatch_semaphore_signal(semaphore)
			case .Completed, .Interrupted:
				dispatch_semaphore_signal(semaphore)
			}
		}
		
		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
		return result
	}

	/// Starts the producer, then blocks, waiting for the last value.
	@warn_unused_result(message="Did you forget to check the result?")
	public func last() -> Result<Value, Error>? {
		return takeLast(1).single()
	}

	/// Starts the producer, then blocks, waiting for completion.
	@warn_unused_result(message="Did you forget to check the result?")
	public func wait() -> Result<(), Error> {
		return then(SignalProducer<(), Error>(value: ())).last() ?? .Success(())
	}
}
