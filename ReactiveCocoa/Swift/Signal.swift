import Foundation
import Result

/// A push-driven stream that sends Events over time, parameterized by the type
/// of values being sent (`Value`) and the type of failure that can occur (`Error`).
/// If no failures should be possible, NoError can be specified for `Error`.
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
public final class Signal<Value, Error: ErrorType> {
	public typealias Observer = ReactiveCocoa.Observer<Value, Error>

	private let atomicObservers: Atomic<Bag<Observer>?> = Atomic(Bag())

	/// Initializes a Signal that will immediately invoke the given generator,
	/// then forward events sent to the given observer.
	///
	/// The disposable returned from the closure will be automatically disposed
	/// if a terminating event is sent to the observer. The Signal itself will
	/// remain alive until the observer is released.
	public init(@noescape _ generator: Observer -> Disposable?) {

		/// Used to ensure that events are serialized during delivery to observers.
		let sendLock = NSLock()
		sendLock.name = "org.reactivecocoa.ReactiveCocoa.Signal"

		let generatorDisposable = SerialDisposable()

		/// When set to `true`, the Signal should interrupt as soon as possible.
		let interrupted = Atomic(false)

		let observer = Observer { event in
			if case .Interrupted = event {
				// Normally we disallow recursive events, but
				// Interrupted is kind of a special snowflake, since it
				// can inadvertently be sent by downstream consumers.
				//
				// So we'll flag Interrupted events specially, and if it
				// happened to occur while we're sending something else,
				// we'll wait to deliver it.
				interrupted.value = true

				if sendLock.tryLock() {
					self.interrupt()
					sendLock.unlock()

					generatorDisposable.dispose()
				}

			} else {
				if let observers = (event.isTerminating ? self.atomicObservers.swap(nil) : self.atomicObservers.value) {
					sendLock.lock()

					for observer in observers {
						observer.action(event)
					}

					let shouldInterrupt = !event.isTerminating && interrupted.value
					if shouldInterrupt {
						self.interrupt()
					}

					sendLock.unlock()

					if event.isTerminating || shouldInterrupt {
						// Dispose only after notifying observers, so disposal logic
						// is consistently the last thing to run.
						generatorDisposable.dispose()
					}
				}
			}
		}

		generatorDisposable.innerDisposable = generator(observer)
	}

	/// A Signal that never sends any events to its observers.
	public static var never: Signal {
		return self.init { _ in nil }
	}

	/// A Signal that completes immediately without emitting any value.
	public static var empty: Signal {
		return self.init { observer in
			observer.sendCompleted()
			return nil
		}
	}

	/// Creates a Signal that will be controlled by sending events to the given
	/// observer.
	///
	/// The Signal will remain alive until a terminating event is sent to the
	/// observer.
	public static func pipe() -> (Signal, Observer) {
		var observer: Observer!
		let signal = self.init { innerObserver in
			observer = innerObserver
			return nil
		}

		return (signal, observer)
	}

	/// Interrupts all observers and terminates the stream.
	private func interrupt() {
		if let observers = self.atomicObservers.swap(nil) {
			for observer in observers {
				observer.sendInterrupted()
			}
		}
	}

	/// Observes the Signal by sending any future events to the given observer. If
	/// the Signal has already terminated, the observer will immediately receive an
	/// `Interrupted` event.
	///
	/// Returns a Disposable which can be used to disconnect the observer. Disposing
	/// of the Disposable will have no effect on the Signal itself.
	public func observe(observer: Observer) -> Disposable? {
		var token: RemovalToken?
		atomicObservers.modify { observers in
			guard var observers = observers else {
				return nil
			}

			token = observers.insert(observer)
			return observers
		}

		if let token = token {
			return ActionDisposable { [weak self] in
				self?.atomicObservers.modify { observers in
					guard var observers = observers else {
						return nil
					}

					observers.removeValueForToken(token)
					return observers
				}
			}
		} else {
			observer.sendInterrupted()
			return nil
		}
	}
}

public protocol SignalType {
	/// The type of values being sent on the signal.
	associatedtype Value
	/// The type of error that can occur on the signal. If errors aren't possible
	/// then `NoError` can be used.
	associatedtype Error: ErrorType

	/// Extracts a signal from the receiver.
	var signal: Signal<Value, Error> { get }

	/// Observes the Signal by sending any future events to the given observer.
	func observe(observer: Signal<Value, Error>.Observer) -> Disposable?
}

extension Signal: SignalType {
	public var signal: Signal {
		return self
	}
}

extension SignalType {
	/// Convenience override for observe(_:) to allow trailing-closure style
	/// invocations.
	public func observe(action: Signal<Value, Error>.Observer.Action) -> Disposable? {
		return observe(Observer(action))
	}

	/// Observes the Signal by invoking the given callback when `next` events are
	/// received.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callbacks. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeNext(next: Value -> Void) -> Disposable? {
		return observe(Observer(next: next))
	}

	/// Observes the Signal by invoking the given callback when a `completed` event is
	/// received.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callback. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeCompleted(completed: () -> Void) -> Disposable? {
		return observe(Observer(completed: completed))
	}
	
	/// Observes the Signal by invoking the given callback when a `failed` event is
	/// received.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callback. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeFailed(error: Error -> Void) -> Disposable? {
		return observe(Observer(failed: error))
	}
	
	/// Observes the Signal by invoking the given callback when an `interrupted` event is
	/// received. If the Signal has already terminated, the callback will be invoked
	/// immediately.
	///
	/// Returns a Disposable which can be used to stop the invocation of the
	/// callback. Disposing of the Disposable will have no effect on the Signal
	/// itself.
	public func observeInterrupted(interrupted: () -> Void) -> Disposable? {
		return observe(Observer(interrupted: interrupted))
	}

	/// Maps each value in the signal to a new value.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func map<U>(transform: Value -> U) -> Signal<U, Error> {
		return Signal { observer in
			return self.observe { event in
				observer.action(event.map(transform))
			}
		}
	}

	/// Maps errors in the signal to a new error.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func mapError<F>(transform: Error -> F) -> Signal<Value, F> {
		return Signal { observer in
			return self.observe { event in
				observer.action(event.mapError(transform))
			}
		}
	}

	/// Preserves only the values of the signal that pass the given predicate.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func filter(predicate: Value -> Bool) -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe { (event: Event<Value, Error>) -> Void in
				guard let value = event.value else {
					observer.action(event)
					return
				}

				if predicate(value) {
					observer.sendNext(value)
				}
			}
		}
	}
}

extension SignalType where Value: OptionalType {
	/// Unwraps non-`nil` values and forwards them on the returned signal, `nil`
	/// values are dropped.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func ignoreNil() -> Signal<Value.Wrapped, Error> {
		return filter { $0.optional != nil }.map { $0.optional! }
	}
}

extension SignalType {
	/// Returns a signal that will yield the first `count` values from `self`
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func take(count: Int) -> Signal<Value, Error> {
		precondition(count >= 0)

		return Signal { observer in
			if count == 0 {
				observer.sendCompleted()
				return nil
			}

			var taken = 0

			return self.observe { event in
				guard let value = event.value else {
					observer.action(event)
					return
				}

				if taken < count {
					taken += 1
					observer.sendNext(value)
				}

				if taken == count {
					observer.sendCompleted()
				}
			}
		}
	}
}

/// A reference type which wraps an array to auxiliate the collection of values
/// for `collect` operator.
private final class CollectState<Value> {
	var values: [Value] = []

	/// Collects a new value.
	func append(value: Value) {
		values.append(value)
	}

	/// Check if there are any items remaining.
	///
	/// - Note: This method also checks if there weren't collected any values 
	/// and, in that case, it means an empty array should be sent as the result
	/// of collect.
	var isEmpty: Bool {
		/// We use capacity being zero to determine if we haven't collected any 
		/// value since we're keeping the capacity of the array to avoid 
		/// unnecessary and expensive allocations). This also guarantees 
		/// retro-compatibility around the original `collect()` operator.
		return values.isEmpty && values.capacity > 0
	}

	/// Removes all values previously collected if any.
	func flush() {
		// Minor optimization to avoid consecutive allocations. Can
		// be useful for sequences of regular or similar size and to
		// track if any value was ever collected.
		values.removeAll(keepCapacity: true)
	}
}


extension SignalType {

	/// Returns a signal that will yield an array of values when `self` completes.
	///
	/// - Note: When `self` completes without collecting any value, it will send
	/// an empty array of values.
	///
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func collect() -> Signal<[Value], Error> {
		return collect { _,_ in false }
	}

	/// Returns a signal that will yield an array of values until it reaches a 
	/// certain count.
	///
	/// When the count is reached the array is sent and the signal starts over 
	/// yielding a new array of values.
	///
	/// - Precondition: `count` should be greater than zero.
	///
	/// - Note: When `self` completes any remaining values will be sent, the last
	/// array may not have `count` values. Alternatively, if were not collected 
	/// any values will sent an empty array of values.
	///
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func collect(count count: Int) -> Signal<[Value], Error> {
		precondition(count > 0)
		return collect { values in values.count == count }
	}

	/// Returns a signal that will yield an array of values based on a predicate
	/// which matches the values collected.
	///
	/// - parameter predicate: Predicate to match when values should be sent
	/// (returning `true`) or alternatively when they should be collected (where
	/// it should return `false`). The most recent value (`next`) is included in 
	/// `values` and will be the end of the current array of values if the
	/// predicate returns `true`.
	///
	/// - Note: When `self` completes any remaining values will be sent, the last
	/// array may not match `predicate`. Alternatively, if were not collected any 
	/// values will sent an empty array of values.
	///
	/// #### Example
	///
	///     let (signal, observer) = Signal<Int, NoError>.pipe()
	///
	///     signal
	///         .collect { values in values.reduce(0, combine: +) == 8 }
	///         .observeNext { print($0) }
	///
	///     observer.sendNext(1)
	///     observer.sendNext(3)
	///     observer.sendNext(4)
	///     observer.sendNext(7)
	///     observer.sendNext(1)
	///     observer.sendNext(5)
	///     observer.sendNext(6)
	///     observer.sendCompleted()
	///
	///     // Output:
	///     // [1, 3, 4]
	///     // [7, 1]
	///     // [5, 6]
	///
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func collect(predicate: (values: [Value]) -> Bool) -> Signal<[Value], Error> {
		return Signal { observer in
			let state = CollectState<Value>()

			return self.observe { event in
				switch event {
				case let .Next(value):
					state.append(value)
					if predicate(values: state.values) {
						observer.sendNext(state.values)
						state.flush()
					}
				case .Completed:
					if !state.isEmpty {
						observer.sendNext(state.values)
					}
					observer.sendCompleted()
				case let .Failed(error):
					observer.sendFailed(error)
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}

	/// Returns a signal that will yield an array of values based on a predicate
	/// which matches the values collected and the next value.
	///
	/// - parameter predicate: Predicate to match when values should be sent 
	/// (returning `true`) or alternatively when they should be collected (where
	/// it should return `false`). The most recent value (`next`) is not included
	/// in `values` and will be the start of the next array of values if the
	/// predicate returns `true`.
	///
	/// - Note: When `self` completes any remaining values will be sent, the last
	/// array may not match `predicate`. Alternatively, if were not collected any
	/// values will sent an empty array of values.
	///
	/// #### Example
	///
	///     let (signal, observer) = Signal<Int, NoError>.pipe()
	///
	///     signal
	///         .collect { values, next in next == 7 }
	///         .observeNext { print($0) }
	///
	///     observer.sendNext(1)
	///     observer.sendNext(1)
	///     observer.sendNext(7)
	///     observer.sendNext(7)
	///     observer.sendNext(5)
	///     observer.sendNext(6)
	///     observer.sendCompleted()
	///
	///     // Output:
	///     // [1, 1]
	///     // [7]
	///     // [7, 5, 6]
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func collect(predicate: (values: [Value], next: Value) -> Bool) -> Signal<[Value], Error> {
		return Signal { observer in
			let state = CollectState<Value>()

			return self.observe { event in
				switch event {
				case let .Next(value):
					if predicate(values: state.values, next: value) {
						observer.sendNext(state.values)
						state.flush()
					}
					state.append(value)
				case .Completed:
					if !state.isEmpty {
						observer.sendNext(state.values)
					}
					observer.sendCompleted()
				case let .Failed(error):
					observer.sendFailed(error)
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}

	/// Forwards all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func observeOn(scheduler: SchedulerType) -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe { event in
				scheduler.schedule {
					observer.action(event)
				}
			}
		}
	}
}

private final class CombineLatestState<Value> {
	var latestValue: Value?
	var completed = false
}

extension SignalType {
	private func observeWithStates<U>(signalState: CombineLatestState<Value>, _ otherState: CombineLatestState<U>, _ lock: NSLock, _ observer: Signal<(), Error>.Observer) -> Disposable? {
		return self.observe { event in
			switch event {
			case let .Next(value):
				lock.lock()

				signalState.latestValue = value
				if otherState.latestValue != nil {
					observer.sendNext()
				}

				lock.unlock()

			case let .Failed(error):
				observer.sendFailed(error)

			case .Completed:
				lock.lock()

				signalState.completed = true
				if otherState.completed {
					observer.sendCompleted()
				}

				lock.unlock()

			case .Interrupted:
				observer.sendInterrupted()
			}
		}
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each. If either signal is interrupted, the returned signal
	/// will also be interrupted.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func combineLatestWith<U>(otherSignal: Signal<U, Error>) -> Signal<(Value, U), Error> {
		return Signal { observer in
			let lock = NSLock()
			lock.name = "org.reactivecocoa.ReactiveCocoa.combineLatestWith"

			let signalState = CombineLatestState<Value>()
			let otherState = CombineLatestState<U>()

			let onBothNext = {
				observer.sendNext((signalState.latestValue!, otherState.latestValue!))
			}

			let observer = Signal<(), Error>.Observer(next: onBothNext, failed: observer.sendFailed, completed: observer.sendCompleted, interrupted: observer.sendInterrupted)

			let disposable = CompositeDisposable()
			disposable += self.observeWithStates(signalState, otherState, lock, observer)
			disposable += otherSignal.observeWithStates(otherState, signalState, lock, observer)
			
			return disposable
		}
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Failed` and `Interrupted` events are always scheduled immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer in
			return self.observe { event in
				switch event {
				case .Failed, .Interrupted:
					scheduler.schedule {
						observer.action(event)
					}

				case .Next, .Completed:
					let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
					scheduler.scheduleAfter(date) {
						observer.action(event)
					}
				}
			}
		}
	}

	/// Returns a signal that will skip the first `count` values, then forward
	/// everything afterward.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skip(count: Int) -> Signal<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return signal
		}

		return Signal { observer in
			var skipped = 0

			return self.observe { event in
				if case .Next = event where skipped < count {
					skipped += 1
				} else {
					observer.action(event)
				}
			}
		}
	}

	/// Treats all Events from `self` as plain values, allowing them to be manipulated
	/// just like any other value.
	///
	/// In other words, this brings Events “into the monad.”
	///
	/// When a Completed or Failed event is received, the resulting signal will send
	/// the Event itself and then complete. When an Interrupted event is received,
	/// the resulting signal will send the Event itself and then interrupt.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func materialize() -> Signal<Event<Value, Error>, NoError> {
		return Signal { observer in
			return self.observe { event in
				observer.sendNext(event)

				switch event {
				case .Interrupted:
					observer.sendInterrupted()

				case .Completed, .Failed:
					observer.sendCompleted()

				case .Next:
					break
				}
			}
		}
	}
}

extension SignalType where Value: EventType, Error == NoError {
	/// The inverse of materialize(), this will translate a signal of `Event`
	/// _values_ into a signal of those events themselves.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func dematerialize() -> Signal<Value.Value, Value.Error> {
		return Signal<Value.Value, Value.Error> { observer in
			return self.observe { event in
				switch event {
				case let .Next(innerEvent):
					observer.action(innerEvent.event)

				case .Failed:
					fatalError("NoError is impossible to construct")

				case .Completed:
					observer.sendCompleted()

				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}
}

extension SignalType {
	/// Injects side effects to be performed upon the specified signal events.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func on(event event: (Event<Value, Error> -> Void)? = nil, failed: (Error -> Void)? = nil, completed: (() -> Void)? = nil, interrupted: (() -> Void)? = nil, terminated: (() -> Void)? = nil, disposed: (() -> Void)? = nil, next: (Value -> Void)? = nil) -> Signal<Value, Error> {
		return Signal { observer in
			let disposable = CompositeDisposable()

			_ = disposed.map(disposable.addDisposable)

			disposable += signal.observe { receivedEvent in
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

			return disposable
		}
	}
}

private struct SampleState<Value> {
	var latestValue: Value? = nil
	var signalCompleted: Bool = false
	var samplerCompleted: Bool = false
}

extension SignalType {
	/// Forwards the latest value from `self` with the value from `sampler` as a tuple,
	/// only when`sampler` sends a Next event.
	///
	/// If `sampler` fires before a value has been observed on `self`, nothing
	/// happens.
	///
	/// Returns a signal that will send values from `self` and `sampler`, sampled (possibly
	/// multiple times) by `sampler`, then complete once both input signals have
	/// completed, or interrupt if either input signal is interrupted.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func sampleWith<T>(sampler: Signal<T, NoError>) -> Signal<(Value, T), Error> {
		return Signal { observer in
			let state = Atomic(SampleState<Value>())
			let disposable = CompositeDisposable()

			disposable += self.observe { event in
				switch event {
				case let .Next(value):
					state.modify { st in
						var st = st
						st.latestValue = value
						return st
					}
				case let .Failed(error):
					observer.sendFailed(error)
				case .Completed:
					let oldState = state.modify { st in
						var st = st
						st.signalCompleted = true
						return st
					}
					
					if oldState.samplerCompleted {
						observer.sendCompleted()
					}
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
			
			disposable += sampler.observe { event in
				switch event {
				case .Next(let samplerValue):
					if let value = state.value.latestValue {
						observer.sendNext((value, samplerValue))
					}
				case .Completed:
					let oldState = state.modify { st in
						var st = st
						st.samplerCompleted = true
						return st
					}
					
					if oldState.signalCompleted {
						observer.sendCompleted()
					}
				case .Interrupted:
					observer.sendInterrupted()
				case .Failed:
					break
				}
			}

			return disposable
		}
	}
	
	/// Forwards the latest value from `self` whenever `sampler` sends a Next
	/// event.
	///
	/// If `sampler` fires before a value has been observed on `self`, nothing
	/// happens.
	///
	/// Returns a signal that will send values from `self`, sampled (possibly
	/// multiple times) by `sampler`, then complete once both input signals have
	/// completed, or interrupt if either input signal is interrupted.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func sampleOn(sampler: Signal<(), NoError>) -> Signal<Value, Error> {
		return sampleWith(sampler)
			.map { $0.0 }
	}

	/// Forwards events from `self` until `trigger` sends a Next or Completed
	/// event, at which point the returned signal will complete.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeUntil(trigger: Signal<(), NoError>) -> Signal<Value, Error> {
		return Signal { observer in
			let disposable = CompositeDisposable()
			disposable += self.observe(observer)

			disposable += trigger.observe { event in
				switch event {
				case .Next, .Completed:
					observer.sendCompleted()

				case .Failed, .Interrupted:
					break
				}
			}

			return disposable
		}
	}
	
	/// Does not forward any values from `self` until `trigger` sends a Next or
	/// Completed event, at which point the returned signal behaves exactly like
	/// `signal`.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipUntil(trigger: Signal<(), NoError>) -> Signal<Value, Error> {
		return Signal { observer in
			let disposable = SerialDisposable()
			
			disposable.innerDisposable = trigger.observe { event in
				switch event {
				case .Next, .Completed:
					disposable.innerDisposable = self.observe(observer)
					
				case .Failed, .Interrupted:
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
	public func combinePrevious(initial: Value) -> Signal<(Value, Value), Error> {
		return scan((initial, initial)) { previousCombinedValues, newValue in
			return (previousCombinedValues.1, newValue)
		}
	}

	/// Like `scan`, but sends only the final value and then immediately completes.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func reduce<U>(initial: U, _ combine: (U, Value) -> U) -> Signal<U, Error> {
		// We need to handle the special case in which `signal` sends no values.
		// We'll do that by sending `initial` on the output signal (before taking
		// the last value).
		let (scannedSignalWithInitialValue, outputSignalObserver) = Signal<U, Error>.pipe()
		let outputSignal = scannedSignalWithInitialValue.takeLast(1)

		// Now that we've got takeLast() listening to the piped signal, send that initial value.
		outputSignalObserver.sendNext(initial)

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
	public func scan<U>(initial: U, _ combine: (U, Value) -> U) -> Signal<U, Error> {
		return Signal { observer in
			var accumulator = initial

			return self.observe { event in
				observer.action(event.map { value in
					accumulator = combine(accumulator, value)
					return accumulator
				})
			}
		}
	}
}

extension SignalType where Value: Equatable {
	/// Forwards only those values from `self` which are not duplicates of the
	/// immedately preceding value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipRepeats() -> Signal<Value, Error> {
		return skipRepeats(==)
	}
}

extension SignalType {
	/// Forwards only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value. The first value is always forwarded.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipRepeats(isRepeat: (Value, Value) -> Bool) -> Signal<Value, Error> {
		return self
			.scan((nil, false)) { (accumulated: (Value?, Bool), next: Value) -> (value: Value?, repeated: Bool) in
				switch accumulated.0 {
				case nil:
					return (next, false)
				case let prev? where isRepeat(prev, next):
					return (prev, true)
				case _?:
					return (Optional(next), false)
				}
			}
			.filter { !$0.repeated }
			.map { $0.value }
			.ignoreNil()
	}

	/// Does not forward any values from `self` until `predicate` returns false,
	/// at which point the returned signal behaves exactly like `signal`.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func skipWhile(predicate: Value -> Bool) -> Signal<Value, Error> {
		return Signal { observer in
			var shouldSkip = true

			return self.observe { event in
				switch event {
				case let .Next(value):
					shouldSkip = shouldSkip && predicate(value)
					if !shouldSkip {
						fallthrough
					}

				case .Failed, .Completed, .Interrupted:
					observer.action(event)
				}
			}
		}
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// Returns a signal which passes through `Next`, `Failed`, and `Interrupted`
	/// events from `signal` until `replacement` sends an event, at which point the
	/// returned signal will send that event and switch to passing through events
	/// from `replacement` instead, regardless of whether `self` has sent events
	/// already.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeUntilReplacement(replacement: Signal<Value, Error>) -> Signal<Value, Error> {
		return Signal { observer in
			let disposable = CompositeDisposable()

			let signalDisposable = self.observe { event in
				switch event {
				case .Completed:
					break

				case .Next, .Failed, .Interrupted:
					observer.action(event)
				}
			}

			disposable += signalDisposable
			disposable += replacement.observe { event in
				signalDisposable?.dispose()
				observer.action(event)
			}

			return disposable
		}
	}

	/// Waits until `self` completes and then forwards the final `count` values
	/// on the returned signal.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeLast(count: Int) -> Signal<Value, Error> {
		return Signal { observer in
			var buffer: [Value] = []
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
				case let .Failed(error):
					observer.sendFailed(error)
				case .Completed:
					buffer.forEach(observer.sendNext)
					
					observer.sendCompleted()
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}

	/// Forwards any values from `self` until `predicate` returns false,
	/// at which point the returned signal will complete.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func takeWhile(predicate: Value -> Bool) -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe { event in
				if let value = event.value where !predicate(value) {
					observer.sendCompleted()
				} else {
					observer.action(event)
				}
			}
		}
	}
}

private struct ZipState<Left, Right> {
	var values: (left: [Left], right: [Right]) = ([], [])
	var isCompleted: (left: Bool, right: Bool) = (false, false)

	var isFinished: Bool {
		return (isCompleted.left && values.left.isEmpty) || (isCompleted.right && values.right.isEmpty)
	}
}

extension SignalType {
	/// Zips elements of two signals into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func zipWith<U>(otherSignal: Signal<U, Error>) -> Signal<(Value, U), Error> {
		return Signal { observer in
			let state = Atomic(ZipState<Value, U>())
			let disposable = CompositeDisposable()
			
			let flush = {
				var tuple: (Value, U)?
				var isFinished = false

				state.modify { state in
					guard !state.values.left.isEmpty && !state.values.right.isEmpty else {
						isFinished = state.isFinished
						return state
					}

					var state = state
					tuple = (state.values.left.removeFirst(), state.values.right.removeFirst())
					isFinished = state.isFinished
					return state
				}

				if let tuple = tuple {
					observer.sendNext(tuple)
				}

				if isFinished {
					observer.sendCompleted()
				}
			}
			
			let onFailed = observer.sendFailed
			let onInterrupted = observer.sendInterrupted

			disposable += self.observe { event in
				switch event {
				case let .Next(value):
					state.modify { state in
						var state = state
						state.values.left.append(value)
						return state
					}
					
					flush()
				case let .Failed(error):
					onFailed(error)
				case .Completed:
					state.modify { state in
						var state = state
						state.isCompleted.left = true
						return state
					}
					
					flush()
				case .Interrupted:
					onInterrupted()
				}
			}

			disposable += otherSignal.observe { event in
				switch event {
				case let .Next(value):
					state.modify { state in
						var state = state
						state.values.right.append(value)
						return state
					}
					
					flush()
				case let .Failed(error):
					onFailed(error)
				case .Completed:
					state.modify { state in
						var state = state
						state.isCompleted.right = true
						return state
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
	/// forwarded on the returned signal and `Failure`s sent as `Failed` events.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func attempt(operation: Value -> Result<(), Error>) -> Signal<Value, Error> {
		return attemptMap { value in
			return operation(value).map {
				return value
			}
		}
	}

	/// Applies `operation` to values from `self` with `Success`ful results mapped
	/// on the returned signal and `Failure`s sent as `Failed` events.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func attemptMap<U>(operation: Value -> Result<U, Error>) -> Signal<U, Error> {
		return Signal { observer in
			self.observe { event in
				switch event {
				case let .Next(value):
					operation(value).analysis(
						ifSuccess: observer.sendNext,
						ifFailure: observer.sendFailed
					)
				case let .Failed(error):
					observer.sendFailed(error)
				case .Completed:
					observer.sendCompleted()
				case .Interrupted:
					observer.sendInterrupted()
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
	public func throttle(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer in
			let state: Atomic<ThrottleState<Value>> = Atomic(ThrottleState())
			let schedulerDisposable = SerialDisposable()

			let disposable = CompositeDisposable()
			disposable.addDisposable(schedulerDisposable)

			disposable += self.observe { event in
				guard let value = event.value else {
					schedulerDisposable.innerDisposable = scheduler.schedule {
						observer.action(event)
					}
					return
				}

				var scheduleDate: NSDate!
				state.modify { state in
					var state = state
					state.pendingValue = value

					let proposedScheduleDate = state.previousDate?.dateByAddingTimeInterval(interval) ?? scheduler.currentDate
					scheduleDate = proposedScheduleDate.laterDate(scheduler.currentDate)

					return state
				}

				schedulerDisposable.innerDisposable = scheduler.scheduleAfter(scheduleDate) {
					let previousState = state.modify { state in
						var state = state

						if state.pendingValue != nil {
							state.pendingValue = nil
							state.previousDate = scheduleDate
						}

						return state
					}
					
					if let pendingValue = previousState.pendingValue {
						observer.sendNext(pendingValue)
					}
				}
			}

			return disposable
		}
	}

	/// Debounce values sent by the receiver, such that at least `interval`
	/// seconds pass after the receiver has last sent a value, then
	/// forwards the latest value on the given scheduler.
	///
	/// If multiple values are received before the interval has elapsed, the
	/// latest value is the one that will be passed on.
	///
	/// If the input signal terminates while a value is being debounced, that value
	/// will be discarded and the returned signal will terminate immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func debounce(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)
		
		return self
			.materialize()
			.flatMap(.Latest) { event -> SignalProducer<Event<Value, Error>, NoError> in
				if event.isTerminating {
					return SignalProducer(value: event).observeOn(scheduler)
				} else {
					return SignalProducer(value: event).delay(interval, onScheduler: scheduler)
				}
			}
			.dematerialize()
	}
}

extension SignalType {
	/// Forwards only those values from `self` that have unique identities across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the identities to be retained to check for uniqueness.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func uniqueValues<Identity: Hashable>(transform: Value -> Identity) -> Signal<Value, Error> {
		return Signal { observer in
			var seenValues: Set<Identity> = []
			
			return self
				.observe { event in
					switch event {
					case let .Next(value):
						let identity = transform(value)
						if !seenValues.contains(identity) {
							seenValues.insert(identity)
							fallthrough
						}
						
					case .Failed, .Completed, .Interrupted:
						observer.action(event)
					}
				}
		}
	}
}

extension SignalType where Value: Hashable {
	/// Forwards only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the values to be retained to check for uniqueness. Providing
	/// a function that returns a unique value for each sent value can help you reduce
	/// the memory footprint.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func uniqueValues() -> Signal<Value, Error> {
		return uniqueValues { $0 }
	}
}

private struct ThrottleState<Value> {
	var previousDate: NSDate? = nil
	var pendingValue: Value? = nil
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
public func combineLatest<S: SequenceType, Value, Error where S.Generator.Element == Signal<Value, Error>>(signals: S) -> Signal<[Value], Error> {
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
public func zip<S: SequenceType, Value, Error where S.Generator.Element == Signal<Value, Error>>(signals: S) -> Signal<[Value], Error> {
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
	/// fails with `error` on `scheduler`.
	///
	/// If the interval is 0, the timeout will be scheduled immediately. The signal
	/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func timeoutWithError(error: Error, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer in
			let disposable = CompositeDisposable()
			let date = scheduler.currentDate.dateByAddingTimeInterval(interval)

			disposable += scheduler.scheduleAfter(date) {
				observer.sendFailed(error)
			}

			disposable += self.observe(observer)
			return disposable
		}
	}
}

extension SignalType where Error == NoError {
	/// Promotes a signal that does not generate failures into one that can.
	///
	/// This does not actually cause failures to be generated for the given signal,
	/// but makes it easier to combine with other signals that may fail; for
	/// example, with operators like `combineLatestWith`, `zipWith`, `flatten`, etc.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func promoteErrors<F: ErrorType>(_: F.Type) -> Signal<Value, F> {
		return Signal { observer in
			return self.observe { event in
				switch event {
				case let .Next(value):
					observer.sendNext(value)
				case .Failed:
					fatalError("NoError is impossible to construct")
				case .Completed:
					observer.sendCompleted()
				case .Interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}
}
