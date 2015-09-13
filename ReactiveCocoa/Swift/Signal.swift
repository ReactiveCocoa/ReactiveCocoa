import Result

/// A push-driven stream that sends Events over time, parameterized by the type
/// of values being sent (`T`) and the type of error that can occur (`E`). If no
/// errors should be possible, NoError can be specified for `E`.
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
/// alive until the event stream has terminated.
public final class Signal<T, E: ErrorType> {
	public typealias Observer = Event<T, E>.Sink

	private let atomicObservers: Atomic<Bag<Observer>?> = Atomic(Bag())

	/// Used to ensure that events are serialized during delivery to observers.
	private let sendLock = NSLock()

	/// Initializes a Signal that will immediately invoke the given generator,
	/// then forward events sent to the given observer.
	///
	/// The disposable returned from the closure will be automatically disposed
	/// if a terminating event is sent to the observer. The Signal itself will
	/// remain alive until the observer is released.
	public init(_ generator: Observer -> Disposable?) {
		sendLock.name = "org.reactivecocoa.ReactiveCocoa.Signal"

		let generatorDisposable = SerialDisposable()

		/// When set to `true`, the Signal should interrupt as soon as possible.
		let interrupted = Atomic(false)

		let sink: Observer = { event in
			switch event {
			case .Interrupted:
				// Normally we disallow recursive events, but
				// Interrupted is kind of a special snowflake, since it
				// can inadvertently be sent by downstream consumers.
				//
				// So we'll flag Interrupted events specially, and if it
				// happened to occur while we're sending something else,
				// we'll wait to deliver it.
				interrupted.value = true

				if self.sendLock.tryLock() {
					self.interrupt()
					self.sendLock.unlock()

					generatorDisposable.dispose()
				}

			default:
				if let observers = (event.isTerminating ? self.atomicObservers.swap(nil) : self.atomicObservers.value) {
					self.sendLock.lock()

					for sink in observers {
						sink(event)
					}

					let shouldInterrupt = !event.isTerminating && interrupted.value
					if shouldInterrupt {
						self.interrupt()
					}

					self.sendLock.unlock()

					if event.isTerminating || shouldInterrupt {
						// Dispose only after notifying observers, so disposal logic
						// is consistently the last thing to run.
						generatorDisposable.dispose()
					}
				}
			}
		}

		generatorDisposable.innerDisposable = generator(sink)
	}

	/// A Signal that never sends any events to its observers.
	public class var never: Signal {
		return self.init { _ in nil }
	}

	/// Creates a Signal that will be controlled by sending events to the given
	/// observer (sink).
	///
	/// The Signal will remain alive until a terminating event is sent to the
	/// observer.
	public class func pipe() -> (Signal, Observer) {
		var sink: Observer!
		let signal = self.init { innerSink in
			sink = innerSink
			return nil
		}

		return (signal, sink)
	}

	/// Interrupts all observers and terminates the stream.
	private func interrupt() {
		if let observers = self.atomicObservers.swap(nil) {
			for sink in observers {
				sink(.Interrupted)
			}
		}
	}

	/// Observes the Signal by sending any future events to the given sink. If
	/// the Signal has already terminated, the sink will immediately receive an
	/// `Interrupted` event.
	///
	/// Returns a Disposable which can be used to disconnect the sink. Disposing
	/// of the Disposable will have no effect on the Signal itself.
	public func observe(observer: Observer) -> Disposable? {
		var token: RemovalToken?
		atomicObservers.modify { observers in
			guard var observers = observers else { return nil }

			token = observers.insert(observer)
			return observers
		}

		if let token = token {
			return ActionDisposable {
				atomicObservers.modify { observers in
					guard var observers = observers else { return nil }

					observers.removeValueForToken(token)
					return observers
				}
			}
		} else {
			observer(.Interrupted)
			return nil
		}
	}
}

public protocol SignalType {
	/// The type of values being sent on the signal.
	typealias T
	/// The type of error that can occur on the signal. If errors aren't possible
	/// then `NoError` can be used.
	typealias E: ErrorType

	/// Extracts a signal from the receiver.
	var signal: Signal<T, E> { get }

	/// Observes the Signal by sending any future events to the given sink.
	func observe(observer: Signal<T, E>.Observer) -> Disposable?
}

extension Signal: SignalType {
	public var signal: Signal {
		return self
	}
}

extension SignalType {
	/// Observes the Signal by invoking the given callback when `next` events are
	/// received.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callbacks. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeNext(next: T -> ()) -> Disposable? {
		return observe(Event.sink(next: next))
	}

	/// Observes the Signal by invoking the given callback when a `completed` event is
	/// received.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callback. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeCompleted(completed: () -> ()) -> Disposable? {
		return observe(Event.sink(completed: completed))
	}
	
	/// Observes the Signal by invoking the given callback when an `error` event is
	/// received.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callback. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeError(error: E -> ()) -> Disposable? {
		return observe(Event.sink(error: error))
	}
	
	/// Observes the Signal by invoking the given callback when an `interrupted` event is
	/// received. If the Signal has already terminated, the callback will be invoked
	/// immediately.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callback. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeInterrupted(interrupted: () -> ()) -> Disposable? {
		return observe(Event.sink(interrupted: interrupted))
	}

	/// Maps each value in the signal to a new value.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func map<U>(transform: T -> U) -> Signal<U, E> {
		return Signal { observer in
			return self.observe { event in
				observer(event.map(transform))
			}
		}
	}

	/// Maps errors in the signal to a new error.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func mapError<F>(transform: E -> F) -> Signal<T, F> {
		return Signal { observer in
			return self.observe { event in
				observer(event.mapError(transform))
			}
		}
	}

	/// Preserves only the values of the signal that pass the given predicate.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func filter(predicate: T -> Bool) -> Signal<T, E> {
		return Signal { observer in
			return self.observe { event in
				switch event {
				case let .Next(value):
					if predicate(value) {
						sendNext(observer, value)
					}

				default:
					observer(event)
				}
			}
		}
	}
}

/// Describes how multiple producers should be joined together.
public enum FlattenStrategy: Equatable {
	/// The producers should be merged, so that any value received on any of the
	/// input producers will be forwarded immediately to the output producer.
	///
	/// The resulting producer will complete only when all inputs have completed.
	case Merge

	/// The producers should be concatenated, so that their values are sent in the
	/// order of the producers themselves.
	///
	/// The resulting producer will complete only when all inputs have completed.
	case Concat

	/// Only the events from the latest input producer should be considered for
	/// the output. Any producers received before that point will be disposed of.
	///
	/// The resulting producer will complete only when the producer-of-producers and
	/// the latest producer has completed.
	case Latest
}

extension Signal where T: SignalProducerType, E == T.E {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` or an active inner producer emits an error, the returned
	/// signal will forward that error immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<T.T, E> {
		switch strategy {
		case .Merge:
			return signal.merge()

		case .Concat:
			return signal.concat()

		case .Latest:
			return signal.switchToLatest()
		}
	}
}

extension Signal {
	/// Maps each event from `signal` to a new producer, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` or any of the created producers emit an error, the returned
	/// signal will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: T -> SignalProducer<U, E>) -> Signal<U, E> {
		return map(transform).flatten(strategy)
	}
}

extension Signal where T: SignalProducerType, E == T.E {
	/// Returns a signal which sends all the values from producer signal emitted from
	/// `signal`, waiting until each inner producer completes before beginning to
	/// send the values from the next inner producer.
	///
	/// If any of the inner producers emit an error, the returned signal will emit
	/// that error.
	///
	/// The returned signal completes only when `signal` and all producers
	/// emitted from `signal` complete.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	private func concat() -> Signal<T.T, E> {
		return Signal<T.T, E> { [signal = self.signal] observer in
			let disposable = CompositeDisposable()
			let state = ConcatState(observer: observer, disposable: disposable)

			disposable += signal.observe { event in
				switch event {
				case let .Next(value):
					state.enqueueSignalProducer(value.producer)

				case let .Error(error):
					sendError(observer, error)

				case .Completed:
					// Add one last producer to the queue, whose sole job is to
					// "turn out the lights" by completing `observer`.
					state.enqueueSignalProducer(SignalProducer.empty.on(completed: {
						sendCompleted(observer)
					}))

				case .Interrupted:
					sendInterrupted(observer)
				}
			}

			return disposable
		}
	}
}

private final class ConcatState<T, E: ErrorType> {
	/// The observer of a started `concat` producer.
	let observer: Signal<T, E>.Observer

	/// The top level disposable of a started `concat` producer.
	let disposable: CompositeDisposable

	/// The active producer, if any, and the producers waiting to be started.
	let queuedSignalProducers: Atomic<[SignalProducer<T, E>]> = Atomic([])

	init(observer: Signal<T, E>.Observer, disposable: CompositeDisposable) {
		self.observer = observer
		self.disposable = disposable
	}

	func enqueueSignalProducer(producer: SignalProducer<T, E>) {
		if disposable.disposed {
			return
		}

		var shouldStart = true

		queuedSignalProducers.modify { (var queue) in
			// An empty queue means the concat is idle, ready & waiting to start
			// the next producer.
			shouldStart = queue.isEmpty
			queue.append(producer)
			return queue
		}

		if shouldStart {
			startNextSignalProducer(producer)
		}
	}

	func dequeueSignalProducer() -> SignalProducer<T, E>? {
		if disposable.disposed {
			return nil
		}

		var nextSignalProducer: SignalProducer<T, E>?

		queuedSignalProducers.modify { (var queue) in
			// Active producers remain in the queue until completed. Since
			// dequeueing happens at completion of the active producer, the
			// first producer in the queue can be removed.
			if !queue.isEmpty { queue.removeAtIndex(0) }
			nextSignalProducer = queue.first
			return queue
		}

		return nextSignalProducer
	}

	/// Subscribes to the given signal producer.
	func startNextSignalProducer(signalProducer: SignalProducer<T, E>) {
		signalProducer.startWithSignal { signal, disposable in
			let handle = self.disposable.addDisposable(disposable)

			signal.observe { event in
				switch event {
				case .Completed, .Interrupted:
					handle.remove()

					if let nextSignalProducer = self.dequeueSignalProducer() {
						self.startNextSignalProducer(nextSignalProducer)
					}

				default:
					self.observer(event)
				}
			}
		}
	}
}

extension Signal where T: SignalProducerType, E == T.E {
	/// Merges a `signal` of SignalProducers down into a single signal, biased toward the producer
	/// added earlier. Returns a Signal that will forward events from the inner producers as they arrive.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	private func merge() -> Signal<T.T, E> {
		return Signal<T.T, E> { [signal = self.signal] relayObserver in
			let inFlight = Atomic(1)
			let decrementInFlight: () -> () = {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					sendCompleted(relayObserver)
				}
			}

			let disposable = CompositeDisposable()
			signal.observe { event in
				switch event {
				case let .Next(producer):
					producer.startWithSignal { innerSignal, innerDisposable in
						inFlight.modify { $0 + 1 }

						let handle = disposable.addDisposable(innerDisposable)

						innerSignal.observe { event in
							switch event {
							case .Completed, .Interrupted:
								if event.isTerminating {
									handle.remove()
								}

								decrementInFlight()

							default:
								relayObserver(event)
							}
						}
					}

				case let .Error(error):
					sendError(relayObserver, error)

				case .Completed:
					decrementInFlight()

				case .Interrupted:
					sendInterrupted(relayObserver)
				}
			}

			return disposable
		}
	}

	/// Returns a signal that forwards values from the latest signal sent on
	/// `signal`, ignoring values sent on previous inner signal.
	///
	/// An error sent on `signal` or the latest inner signal will be sent on the
	/// returned signal.
	///
	/// The returned signal completes when `signal` and the latest inner
	/// signal have both completed.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	private func switchToLatest() -> Signal<T.T, E> {
		return Signal<T.T, E> { [signal = self.signal] sink in
			let disposable = CompositeDisposable()
			let latestInnerDisposable = SerialDisposable()
			disposable.addDisposable(latestInnerDisposable)

			let state = Atomic(LatestState<T, E>())

			signal.observe { event in
				switch event {
				case let .Next(innerProducer):
					innerProducer.startWithSignal { innerSignal, innerDisposable in
						state.modify { (var state) in
							// When we replace the disposable below, this prevents the
							// generated Interrupted event from doing any work.
							state.replacingInnerSignal = true
							return state
						}

						latestInnerDisposable.innerDisposable = innerDisposable

						state.modify { (var state) in
							state.replacingInnerSignal = false
							state.innerSignalComplete = false
							return state
						}

						innerSignal.observe { event in
							switch event {
							case .Interrupted:
								// If interruption occurred as a result of a new producer
								// arriving, we don't want to notify our observer.
								let original = state.modify { (var state) in
									if !state.replacingInnerSignal {
										state.innerSignalComplete = true
									}

									return state
								}

								if !original.replacingInnerSignal && original.outerSignalComplete {
									sendCompleted(sink)
								}

							case .Completed:
								let original = state.modify { (var state) in
									state.innerSignalComplete = true
									return state
								}

								if original.outerSignalComplete {
									sendCompleted(sink)
								}

							default:
								sink(event)
							}
						}
					}
				case let .Error(error):
					sendError(sink, error)
				case .Completed:
					let original = state.modify { (var state) in
						state.outerSignalComplete = true
						return state
					}

					if original.innerSignalComplete {
						sendCompleted(sink)
					}
				case .Interrupted:
					sendInterrupted(sink)
				}
			}

			return disposable
		}
	}
}

private struct LatestState<T, E: ErrorType> {
	var outerSignalComplete: Bool = false
	var innerSignalComplete: Bool = true
	
	var replacingInnerSignal: Bool = false
}

// Have to extend `Signal` directly to avoid a compiler crash.
extension Signal where T: OptionalType {
	/// Unwraps non-`nil` values and forwards them on the returned signal, `nil`
	/// values are dropped.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func ignoreNil() -> Signal<T.T, E> {
		return filter { $0.optional != nil }.map { $0.optional! }
	}
}

extension SignalType {
	/// Returns a signal that will yield the first `count` values from `self`
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func take(count: Int) -> Signal<T, E> {
		precondition(count >= 0)

		return Signal { observer in
			if count == 0 {
				sendCompleted(observer)
				return nil
			}

			var taken = 0

			return self.observe { event in
				switch event {
				case let .Next(value):
					if taken < count {
						taken++
						sendNext(observer, value)
					}

					if taken == count {
						sendCompleted(observer)
					}

				default:
					observer(event)
				}
			}
		}
	}
}

/// A reference type which wraps an array to avoid copying it for performance and
/// memory usage optimization.
private final class CollectState<T> {
	var values: [T] = []

	func append(value: T) -> Self {
		values.append(value)
		return self
	}
}

extension SignalType {
	/// Returns a signal that will yield an array of values when `self` completes.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func collect() -> Signal<[T], E> {
		return signal
			.reduce(CollectState()) { $0.append($1) }
			.map { $0.values }
	}

	/// Forwards all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func observeOn(scheduler: SchedulerType) -> Signal<T, E> {
		return Signal { observer in
			return self.observe { event in
				scheduler.schedule {
					observer(event)
				}
			}
		}
	}
}

private final class CombineLatestState<T> {
	var latestValue: T?
	var completed = false
}

private func observeWithStates<T, U, E>(signal: Signal<T, E>, _ signalState: CombineLatestState<T>, _ otherState: CombineLatestState<U>, _ lock: NSLock, _ onBothNext: () -> (), _ onError: E -> (), _ onBothCompleted: () -> (), _ onInterrupted: () -> ()) -> Disposable? {
	return signal.observe { event in
		switch event {
		case let .Next(value):
			lock.lock()
			
			signalState.latestValue = value
			if otherState.latestValue != nil {
				onBothNext()
			}
			
			lock.unlock()
		case let .Error(error):
			onError(error)
		case .Completed:
			lock.lock()
			
			signalState.completed = true
			if otherState.completed {
				onBothCompleted()
			}
			
			lock.unlock()
		case .Interrupted:
			onInterrupted()
		}
	}
}

extension SignalType {
	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each. If either signal is interrupted, the returned signal
	/// will also be interrupted.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func combineLatestWith<U>(otherSignal: Signal<U, E>) -> Signal<(T, U), E> {
		return Signal { observer in
			let lock = NSLock()
			lock.name = "org.reactivecocoa.ReactiveCocoa.combineLatestWith"

			let signalState = CombineLatestState<T>()
			let otherState = CombineLatestState<U>()
			
			let onBothNext = { () -> () in
				sendNext(observer, (signalState.latestValue!, otherState.latestValue!))
			}
			
			let onError = { sendError(observer, $0) }
			let onBothCompleted = { sendCompleted(observer) }
			let onInterrupted = { sendInterrupted(observer) }

			let disposable = CompositeDisposable()
			disposable += observeWithStates(self.signal, signalState, otherState, lock, onBothNext, onError, onBothCompleted, onInterrupted)
			disposable += observeWithStates(otherSignal, otherState, signalState, lock, onBothNext, onError, onBothCompleted, onInterrupted)
			
			return disposable
		}
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Error` and `Interrupted` events are always scheduled immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<T, E> {
		precondition(interval >= 0)

		return Signal { observer in
			return self.observe { event in
				switch event {
				case .Error, .Interrupted:
					scheduler.schedule {
						observer(event)
					}

				default:
					let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
					scheduler.scheduleAfter(date) {
						observer(event)
					}
				}
			}
		}
	}

	/// Returns a signal that will skip the first `count` values, then forward
	/// everything afterward.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skip(count: Int) -> Signal<T, E> {
		precondition(count >= 0)

		if (count == 0) {
			return signal
		}

		return Signal { observer in
			var skipped = 0

			return self.observe { event in
				switch event {
				case .Next:
					if skipped >= count {
						fallthrough
					} else {
						skipped++
					}

				default:
					observer(event)
				}
			}
		}
	}

	/// Treats all Events from `self` as plain values, allowing them to be manipulated
	/// just like any other value.
	///
	/// In other words, this brings Events “into the monad.”
	///
	/// When a Completed or Error event is received, the resulting signal will send
	/// the Event itself and then complete. When an Interrupted event is received,
	/// the resulting signal will send the Event itself and then interrupt.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func materialize() -> Signal<Event<T, E>, NoError> {
		return Signal { observer in
			return self.observe { event in
				sendNext(observer, event)

				switch event {
				case .Interrupted:
					sendInterrupted(observer)

				case .Completed, .Error:
					sendCompleted(observer)

				case .Next:
					break
				}
			}
		}
	}
}

// Have to extend `Signal` directly to avoid a compiler crash.
extension Signal where T: EventType, E: NoError {
	/// The inverse of materialize(), this will translate a signal of `Event`
	/// _values_ into a signal of those events themselves.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func dematerialize() -> Signal<T.T, T.E> {
		return Signal<T.T, T.E> { observer in
			return self.observe { event in
				switch event {
				case let .Next(innerEvent):
					observer(innerEvent.event)

				case .Error:
					fatalError("NoError is impossible to construct")

				case .Completed:
					sendCompleted(observer)

				case .Interrupted:
					sendInterrupted(observer)
				}
			}
		}
	}
}

private struct SampleState<T> {
	var latestValue: T? = nil
	var signalCompleted: Bool = false
	var samplerCompleted: Bool = false
}

extension SignalType {
	/// Forwards the latest value from `signal` whenever `sampler` sends a Next
	/// event.
	///
	/// If `sampler` fires before a value has been observed on `signal`, nothing
	/// happens.
	///
	/// Returns a signal that will send values from `signal`, sampled (possibly
	/// multiple times) by `sampler`, then complete once both input signals have
	/// completed, or interrupt if either input signal is interrupted.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func sampleOn(sampler: Signal<(), NoError>) -> Signal<T, E> {
		return Signal { observer in
			let state = Atomic(SampleState<T>())
			let disposable = CompositeDisposable()

			disposable += self.observe { event in
				switch event {
				case let .Next(value):
					state.modify { (var st) in
						st.latestValue = value
						return st
					}
				case let .Error(error):
					sendError(observer, error)
				case .Completed:
					let oldState = state.modify { (var st) in
						st.signalCompleted = true
						return st
					}
					
					if oldState.samplerCompleted {
						sendCompleted(observer)
					}
				case .Interrupted:
					sendInterrupted(observer)
				}
			}
			
			disposable += sampler.observe { event in
				switch event {
				case .Next(_):
					if let value = state.value.latestValue {
						sendNext(observer, value)
					}
				case .Completed:
					let oldState = state.modify { (var st) in
						st.samplerCompleted = true
						return st
					}
					
					if oldState.signalCompleted {
						sendCompleted(observer)
					}
				case .Interrupted:
					sendInterrupted(observer)
				default:
					break
				}
			}

			return disposable
		}
	}

	/// Forwards events from `self` until `trigger` sends a Next or Completed
	/// event, at which point the returned signal will complete.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeUntil(trigger: Signal<(), NoError>) -> Signal<T, E> {
		return Signal { observer in
			let disposable = CompositeDisposable()
			disposable += self.observe(observer)

			disposable += trigger.observe { event in
				switch event {
				case .Next, .Completed:
					sendCompleted(observer)

				case .Error, .Interrupted:
					break
				}
			}

			return disposable
		}
	}

	/// Forwards events from `self` with history: values of the returned signal
	/// are a tuple whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member when `self`
	/// sends its first value.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func combinePrevious(initial: T) -> Signal<(T, T), E> {
		return scan((initial, initial)) { previousCombinedValues, newValue in
			return (previousCombinedValues.1, newValue)
		}
	}

	/// Like `scan`, but sends only the final value and then immediately completes.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func reduce<U>(initial: U, _ combine: (U, T) -> U) -> Signal<U, E> {
		// We need to handle the special case in which `signal` sends no values.
		// We'll do that by sending `initial` on the output signal (before taking
		// the last value).
		let (scannedSignalWithInitialValue, outputSignalObserver) = Signal<U, E>.pipe()
		let outputSignal = scannedSignalWithInitialValue.takeLast(1)

		// Now that we've got takeLast() listening to the piped signal, send that initial value.
		sendNext(outputSignalObserver, initial)

		// Pipe the scanned input signal into the output signal.
		scan(initial, combine).observe(outputSignalObserver)

		return outputSignal
	}

	/// Aggregates `selfs`'s values into a single combined value. When `self` emits
	/// its first value, `combine` is invoked with `initial` as the first argument and
	/// that emitted value as the second argument. The result is emitted from the
	/// signal returned from `scan`. That result is then passed to `combine` as the
	/// first argument when the next value is emitted, and so on.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func scan<U>(initial: U, _ combine: (U, T) -> U) -> Signal<U, E> {
		return Signal { observer in
			var accumulator = initial

			return self.observe { event in
				observer(event.map { value in
					accumulator = combine(accumulator, value)
					return accumulator
				})
			}
		}
	}
}

extension SignalType where T: Equatable {
	/// Forwards only those values from `self` which are not duplicates of the
	/// immedately preceding value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipRepeats() -> Signal<T, E> {
		return skipRepeats { $0 == $1 }
	}
}

extension SignalType {
	/// Forwards only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipRepeats(isRepeat: (T, T) -> Bool) -> Signal<T, E> {
		return signal
			.map { Optional($0) }
			.combinePrevious(nil)
			.filter { (a, b) in
				if let a = a, b = b where isRepeat(a, b) {
					return false
				} else {
					return true
				}
			}
			.map { $0.1! }
	}

	/// Does not forward any values from `self` until `predicate` returns false,
	/// at which point the returned signal behaves exactly like `signal`.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipWhile(predicate: T -> Bool) -> Signal<T, E> {
		return Signal { observer in
			var shouldSkip = true

			return self.observe { event in
				switch event {
				case let .Next(value):
					shouldSkip = shouldSkip && predicate(value)
					if !shouldSkip {
						fallthrough
					}

				default:
					observer(event)
				}
			}
		}
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// Returns a signal which passes through `Next`, `Error`, and `Interrupted`
	/// events from `signal` until `replacement` sends an event, at which point the
	/// returned signal will send that event and switch to passing through events
	/// from `replacement` instead, regardless of whether `self` has sent events
	/// already.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeUntilReplacement(replacement: Signal<T, E>) -> Signal<T, E> {
		return Signal { observer in
			let disposable = CompositeDisposable()

			let signalDisposable = self.observe { event in
				switch event {
				case .Completed:
					break

				case .Next, .Error, .Interrupted:
					observer(event)
				}
			}

			disposable += signalDisposable
			disposable += replacement.observe { event in
				signalDisposable?.dispose()
				observer(event)
			}

			return disposable
		}
	}

	/// Waits until `self` completes and then forwards the final `count` values
	/// on the returned signal.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeLast(count: Int) -> Signal<T, E> {
		return Signal { observer in
			var buffer = [T]()
			buffer.reserveCapacity(count)

			return self.observe { event in
				switch event {
				case let .Next(value):
					// To avoid exceeding the reserved capacity of the buffer, we remove then add.
					// Remove elements until we have room to add one more.
					while (buffer.count + 1) > count {
						buffer.removeAtIndex(0)
					}
					
					buffer.append(value)
				case let .Error(error):
					sendError(observer, error)
				case .Completed:
					for bufferedValue in buffer {
						sendNext(observer, bufferedValue)
					}
					
					sendCompleted(observer)
				case .Interrupted:
					sendInterrupted(observer)
				}
			}
		}
	}

	/// Forwards any values from `self` until `predicate` returns false,
	/// at which point the returned signal will complete.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeWhile(predicate: T -> Bool) -> Signal<T, E> {
		return Signal { observer in
			return self.observe { event in
				switch event {
				case let .Next(value):
					if predicate(value) {
						fallthrough
					} else {
						sendCompleted(observer)
					}

				default:
					observer(event)
				}
			}
		}
	}
}

private struct ZipState<T> {
	var values: [T] = []
	var completed = false

	var isFinished: Bool {
		return values.isEmpty && completed
	}
}

extension SignalType {
	/// Zips elements of two signals into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func zipWith<U>(otherSignal: Signal<U, E>) -> Signal<(T, U), E> {
		return Signal { observer in
			let initialStates: (ZipState<T>, ZipState<U>) = (ZipState(), ZipState())
			let states: Atomic<(ZipState<T>, ZipState<U>)> = Atomic(initialStates)
			let disposable = CompositeDisposable()
			
			let flush = { () -> () in
				var originalStates: (ZipState<T>, ZipState<U>)!
				states.modify { states in
					originalStates = states
					
					var updatedStates = states
					let extractCount = min(states.0.values.count, states.1.values.count)
					
					updatedStates.0.values.removeRange(0 ..< extractCount)
					updatedStates.1.values.removeRange(0 ..< extractCount)
					return updatedStates
				}
				
				while !originalStates.0.values.isEmpty && !originalStates.1.values.isEmpty {
					let left = originalStates.0.values.removeAtIndex(0)
					let right = originalStates.1.values.removeAtIndex(0)
					sendNext(observer, (left, right))
				}
				
				if originalStates.0.isFinished || originalStates.1.isFinished {
					sendCompleted(observer)
				}
			}
			
			let onError = { sendError(observer, $0) }
			let onInterrupted = { sendInterrupted(observer) }

			disposable += self.observe { event in
				switch event {
				case let .Next(value):
					states.modify { (var states) in
						states.0.values.append(value)
						return states
					}
					
					flush()
				case let .Error(error):
					onError(error)
				case .Completed:
					states.modify { (var states) in
						states.0.completed = true
						return states
					}
					
					flush()
				case .Interrupted:
					onInterrupted()
				}
			}

			disposable += otherSignal.observe { event in
				switch event {
				case let .Next(value):
					states.modify { (var states) in
						states.1.values.append(value)
						return states
					}
					
					flush()
				case let .Error(error):
					onError(error)
				case .Completed:
					states.modify { (var states) in
						states.1.completed = true
						return states
					}
					
					flush()
				case .Interrupted:
					onInterrupted()
				}
			}
			
			return disposable
		}
	}

	/// Applies `operation` to values from `self` with `Success`ful results
	/// forwarded on the returned signal and `Failure`s sent as `Error` events.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func attempt(operation: T -> Result<(), E>) -> Signal<T, E> {
		return attemptMap { value in
			return operation(value).map {
				return value
			}
		}
	}

	/// Applies `operation` to values from `self` with `Success`ful results mapped
	/// on the returned signal and `Failure`s sent as `Error` events.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func attemptMap<U>(operation: T -> Result<U, E>) -> Signal<U, E> {
		return Signal { observer in
			self.observe { event in
				switch event {
				case let .Next(value):
					operation(value).analysis(ifSuccess: { value in
						sendNext(observer, value)
						}, ifFailure: { error in
							sendError(observer, error)
					})
				case let .Error(error):
					sendError(observer, error)
				case .Completed:
					sendCompleted(observer)
				case .Interrupted:
					sendInterrupted(observer)
				}
			}
		}
	}

	/// Throttle values sent by the receiver, so that at least `interval`
	/// seconds pass between each, then forwards them on the given scheduler.
	///
	/// If multiple values are received before the interval has elapsed, the
	/// latest value is the one that will be passed on.
	///
	/// If the input signal terminates while a value is being throttled, that value
	/// will be discarded and the returned signal will terminate immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func throttle(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<T, E> {
		precondition(interval >= 0)

		return Signal { observer in
			let state: Atomic<ThrottleState<T>> = Atomic(ThrottleState())
			let schedulerDisposable = SerialDisposable()

			let disposable = CompositeDisposable()
			disposable.addDisposable(schedulerDisposable)

			disposable += self.observe { event in
				switch event {
				case let .Next(value):
					var scheduleDate: NSDate!
					state.modify { (var state) in
						state.pendingValue = value

						let proposedScheduleDate = state.previousDate?.dateByAddingTimeInterval(interval) ?? scheduler.currentDate
						scheduleDate = proposedScheduleDate.laterDate(scheduler.currentDate)

						return state
					}

					schedulerDisposable.innerDisposable = scheduler.scheduleAfter(scheduleDate) {
						let previousState = state.modify { (var state) in
							if state.pendingValue != nil {
								state.pendingValue = nil
								state.previousDate = scheduleDate
							}

							return state
						}
						
						if let pendingValue = previousState.pendingValue {
							sendNext(observer, pendingValue)
						}
					}

				default:
					schedulerDisposable.innerDisposable = scheduler.schedule {
						observer(event)
					}
				}
			}

			return disposable
		}
	}
}

private struct ThrottleState<T> {
	var previousDate: NSDate? = nil
	var pendingValue: T? = nil
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>) -> Signal<(A, B), Error> {
	return a.combineLatestWith(b)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) -> Signal<(A, B, C), Error> {
	return combineLatest(a, b)
		.combineLatestWith(c)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) -> Signal<(A, B, C, D), Error> {
	return combineLatest(a, b, c)
		.combineLatestWith(d)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, E, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) -> Signal<(A, B, C, D, E), Error> {
	return combineLatest(a, b, c, d)
		.combineLatestWith(e)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, E, F, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) -> Signal<(A, B, C, D, E, F), Error> {
	return combineLatest(a, b, c, d, e)
		.combineLatestWith(f)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, E, F, G, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) -> Signal<(A, B, C, D, E, F, G), Error> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatestWith(g)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, E, F, G, H, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) -> Signal<(A, B, C, D, E, F, G, H), Error> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatestWith(h)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, E, F, G, H, I, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) -> Signal<(A, B, C, D, E, F, G, H, I), Error> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatestWith(i)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<A, B, C, D, E, F, G, H, I, J, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) -> Signal<(A, B, C, D, E, F, G, H, I, J), Error> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatestWith(j)
		.map(repack)
}

/// Combines the values of all the given signals, in the manner described by
/// `combineLatestWith`. No events will be sent if the sequence is empty.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func combineLatest<S: SequenceType, T, Error where S.Generator.Element == Signal<T, Error>>(signals: S) -> Signal<[T], Error> {
	var generator = signals.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { signal, next in
			signal.combineLatestWith(next).map { $0.0 + [$0.1] }
		}
	}
	
	return .never
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>) -> Signal<(A, B), Error> {
	return a.zipWith(b)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) -> Signal<(A, B, C), Error> {
	return zip(a, b)
		.zipWith(c)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) -> Signal<(A, B, C, D), Error> {
	return zip(a, b, c)
		.zipWith(d)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, E, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) -> Signal<(A, B, C, D, E), Error> {
	return zip(a, b, c, d)
		.zipWith(e)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, E, F, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) -> Signal<(A, B, C, D, E, F), Error> {
	return zip(a, b, c, d, e)
		.zipWith(f)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, E, F, G, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) -> Signal<(A, B, C, D, E, F, G), Error> {
	return zip(a, b, c, d, e, f)
		.zipWith(g)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, E, F, G, H, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) -> Signal<(A, B, C, D, E, F, G, H), Error> {
	return zip(a, b, c, d, e, f, g)
		.zipWith(h)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, E, F, G, H, I, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) -> Signal<(A, B, C, D, E, F, G, H, I), Error> {
	return zip(a, b, c, d, e, f, g, h)
		.zipWith(i)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<A, B, C, D, E, F, G, H, I, J, Error>(a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) -> Signal<(A, B, C, D, E, F, G, H, I, J), Error> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zipWith(j)
		.map(repack)
}

/// Zips the values of all the given signals, in the manner described by
/// `zipWith`. No events will be sent if the sequence is empty.
@warn_unused_result(message="Did you forget to call `observe` on the signal?")
public func zip<S: SequenceType, T, Error where S.Generator.Element == Signal<T, Error>>(signals: S) -> Signal<[T], Error> {
	var generator = signals.generate()
	if let first = generator.next() {
		let initial = first.map { [$0] }
		return GeneratorSequence(generator).reduce(initial) { signal, next in
			signal.zipWith(next).map { $0.0 + [$0.1] }
		}
	}
	
	return .never
}

extension SignalType {
	/// Forwards events from `self` until `interval`. Then if signal isn't completed yet,
	/// errors with `error` on `scheduler`.
	///
	/// If the interval is 0, the timeout will be scheduled immediately. The signal
	/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func timeoutWithError(error: E, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<T, E> {
		precondition(interval >= 0)

		return Signal { observer in
			let disposable = CompositeDisposable()
			let date = scheduler.currentDate.dateByAddingTimeInterval(interval)

			disposable += scheduler.scheduleAfter(date) {
				sendError(observer, error)
			}

			disposable += self.observe(observer)
			return disposable
		}
	}
}

extension SignalType where E: NoError {
	/// Promotes a signal that does not generate errors into one that can.
	///
	/// This does not actually cause errors to be generated for the given signal,
	/// but makes it easier to combine with other signals that may error; for
	/// example, with operators like `combineLatestWith`, `zipWith`, `flatten`, etc.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func promoteErrors<F: ErrorType>(_: F.Type) -> Signal<T, F> {
		return Signal { observer in
			return self.observe { event in
				switch event {
				case let .Next(value):
					sendNext(observer, value)
				case .Error(_):
					fatalError("NoError is impossible to construct")
				case .Completed:
					sendCompleted(observer)
				case .Interrupted:
					sendInterrupted(observer)
				}
			}
		}
	}
}
