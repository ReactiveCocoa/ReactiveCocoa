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
public final class Signal<Value, Error: ErrorProtocol> {
	public typealias Observer = ReactiveCocoa.Observer<Value, Error>

	private let atomicObservers: Atomic<Bag<Observer>?> = Atomic(Bag())

	public var hasTerminated: Bool {
		return atomicObservers.value == nil
	}

	/// Initializes a Signal that will immediately invoke the given generator,
	/// then forward events sent to the given observer.
	///
	/// The disposable returned from the closure will be automatically disposed
	/// if a terminating event is sent to the observer. The Signal itself will
	/// remain alive until the observer is released.
	public init(_ generator: @noescape (Observer) throws -> Void) rethrows {

		/// Used to ensure that events are serialized during delivery to observers.
		let sendLock = Lock()
		sendLock.name = "org.reactivecocoa.ReactiveCocoa.Signal"

		/// When set to `true`, the Signal should interrupt as soon as possible.
		let interrupted = Atomic(false)

		let observer = Observer { event in
			if case .interrupted = event {
				// Normally we disallow recursive events, but
				// Interrupted is kind of a special snowflake, since it
				// can inadvertently be sent by downstream consumers.
				//
				// So we'll flag Interrupted events specially, and if it
				// happened to occur while we're sending something else,
				// we'll wait to deliver it.
				interrupted.value = true

				if sendLock.try() {
					self.interrupt()
					sendLock.unlock()
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
				}
			}
		}

		try generator(observer)
	}

	/// A Signal that never sends any events to its observers.
	public static var never: Signal {
		return self.init { _ in }
	}

	/// A Signal that completes immediately without emitting any value.
	public static var empty: Signal {
		return self.init { observer in
			observer.sendCompleted()
		}
	}

	/// Creates a Signal that will be controlled by sending events to the given
	/// observer.
	///
	/// The Signal will remain alive until a terminating event is sent to the
	/// observer.
	public static func pipe() -> (signal: Signal, observer: Observer) {
		var observer: Observer!
		let signal = self.init { innerObserver in
			observer = innerObserver
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
	/// Use `observe(until:observer:endingEvent:)`, `takeUntil` or a `SignalProducer`
	/// if you need explicit control of the duration of observation.
	public func observe(_ observer: Observer) {
		if observe(removable: observer) == nil {
			observer.sendInterrupted()
		}
	}

	public func observe(until trigger: Signal<(), NoError>, observer: Observer, endingEvent: Event<Value, Error>?) {
		let atomicTriggerToken = Atomic<RemovalToken?>(nil)

		let wrappedObserver = Observer { [weak trigger] event in
			observer.action(event)

			if event.isTerminating {
				if let triggerToken = atomicTriggerToken.swap(nil) {
					trigger?.removeObserver(token: triggerToken)
				}
			}
		}

		guard let observerToken = observe(removable: wrappedObserver) else {
			observer.sendInterrupted()
			return
		}

		let triggerObserver = ReactiveCocoa.Observer<(), NoError> { [weak self] event in
			switch event {
			case .next, .completed:
				self?.removeObserver(token: observerToken)
				_ = endingEvent.map(wrappedObserver.action)
			case .failed, .interrupted:
				break
			}
		}

		guard let triggerToken = trigger.observe(removable: triggerObserver) else {
			/// The trigger has terminated.
			observer.sendInterrupted()
			removeObserver(token: observerToken)
			return
		}

		atomicTriggerToken.value = triggerToken
	}

	private func observe(removable observer: Observer) -> RemovalToken? {
		var token: RemovalToken?

		atomicObservers.modify { observers in
			token = observers?.insert(observer)
		}

		return token
	}

	private func removeObserver(token: RemovalToken) {
		atomicObservers.modify { observers in
			observers?.remove(using: token)
		}
	}

	/// Forwards events from `self` until `trigger` sends a Next or Completed
	/// event, at which point the returned signal will complete.
	public func takeUntil(_ trigger: Signal<(), NoError>) -> Signal<Value, Error> {
		return Signal { observer in
			self.observe(until: trigger, observer: observer, endingEvent: .completed)
		}
	}
}

public protocol SignalProtocol {
	/// The type of values being sent on the signal.
	associatedtype Value
	/// The type of error that can occur on the signal. If errors aren't possible
	/// then `NoError` can be used.
	associatedtype Error: ErrorProtocol

	/// Extracts a signal from the receiver.
	var signal: Signal<Value, Error> { get }

	/// Observes the Signal by sending any future events to the given observer.
	func observe(_ observer: Observer<Value, Error>)

	func observe(until: Signal<(), NoError>, observer: Observer<Value, Error>, endingEvent: Event<Value, Error>?)
	func takeUntil(_ trigger: Signal<(), NoError>) -> Signal<Value, Error>
}

extension Signal: SignalProtocol {
	public var signal: Signal {
		return self
	}
}

extension SignalProtocol {
	/// Convenience override for observe(until:observer:endingEvent:) to silently
	/// detach the observer on `.next` or `.completed` events sent upon `trigger`.
	public func observe(until trigger: Signal<(), NoError>, observer: Observer<Value, Error>) {
		observe(until: trigger, observer: observer, endingEvent: nil)
	}

	/// Convenience override for observe(until:observer:endingEvent:) to silently
	/// detach the observer on `.next` or `.completed` events sent upon `trigger`.
	public func observe(until trigger: Signal<(), NoError>, _ action: Signal<Value, Error>.Observer.Action) {
		observe(until: trigger, observer: Observer(action), endingEvent: nil)
	}

	/// Convenience override for observe(_:) to allow trailing-closure style
	/// invocations.
	public func observe(_ action: Signal<Value, Error>.Observer.Action) {
		observe(Observer(action))
	}

	/// Observes the Signal by invoking the given callback when `next` events are
	/// received.
	public func observeNext(_ next: (Value) -> Void) {
		observe(Observer(next: next))
	}

	/// Observes the Signal by invoking the given callback when terminating events
	/// are received.
	public func observeTerminated(_ action: () -> Void) {
		observe { event in
			if event.isTerminating {
				action()
			}
		}
	}

	/// Observes the Signal by invoking the given callback when a `completed` event is
	/// received.
	public func observeCompleted(_ completed: () -> Void) {
		observe(Observer(completed: completed))
	}
	
	/// Observes the Signal by invoking the given callback when a `failed` event is
	/// received.
	public func observeFailed(_ error: (Error) -> Void) {
		observe(Observer(failed: error))
	}
	
	/// Observes the Signal by invoking the given callback when an `interrupted` event is
	/// received. If the Signal has already terminated, the callback will be invoked
	/// immediately.
	public func observeInterrupted(_ interrupted: () -> Void) {
		observe(Observer(interrupted: interrupted))
	}

	/// Observes the Signal by invoking the given interrupter when terminating events
	/// are received.
	public func observeTerminated(_ interruptor: Interrupter) {
		observeTerminated {
			interruptor.interrupt()
		}
	}

	/// Maps each value in the signal to a new value.
	public func map<U>(_ transform: (Value) -> U) -> Signal<U, Error> {
		return Signal { observer in
			self.observe { event in
				observer.action(event.map(transform))
			}
		}
	}

	/// Maps errors in the signal to a new error.
	public func mapError<F>(_ transform: (Error) -> F) -> Signal<Value, F> {
		return Signal { observer in
			self.observe { event in
				observer.action(event.mapError(transform))
			}
		}
	}

	/// Preserves only the values of the signal that pass the given predicate.
	public func filter(_ predicate: (Value) -> Bool) -> Signal<Value, Error> {
		return Signal { observer in
			self.observe { (event: Event<Value, Error>) -> Void in
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

extension SignalProtocol where Value: OptionalType {
	/// Unwraps non-`nil` values and forwards them on the returned signal, `nil`
	/// values are dropped.
	public func ignoreNil() -> Signal<Value.Wrapped, Error> {
		return filter { $0.optional != nil }.map { $0.optional! }
	}
}

extension SignalProtocol {
	/// Returns a signal that will yield the first `count` values from `self`
	public func takeFirst(_ count: Int = 1) -> Signal<Value, Error> {
		precondition(count >= 0)

		return Signal { observer in
			if count == 0 {
				observer.sendCompleted()
				return
			}

			var taken = 0

			self.observe { event in
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
	func append(_ value: Value) {
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
		values.removeAll(keepingCapacity: true)
	}
}


extension SignalProtocol {

	/// Returns a signal that will yield an array of values when `self` completes.
	///
	/// - Note: When `self` completes without collecting any value, it will send
	/// an empty array of values.
	///
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
	public func collect(every count: Int) -> Signal<[Value], Error> {
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
	public func collect(_ predicate: (values: [Value]) -> Bool) -> Signal<[Value], Error> {
		return Signal { observer in
			let state = CollectState<Value>()

			self.observe { event in
				switch event {
				case let .next(value):
					state.append(value)
					if predicate(values: state.values) {
						observer.sendNext(state.values)
						state.flush()
					}
				case .completed:
					if !state.isEmpty {
						observer.sendNext(state.values)
					}
					observer.sendCompleted()
				case let .failed(error):
					observer.sendFailed(error)
				case .interrupted:
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
	public func collect(_ predicate: (values: [Value], next: Value) -> Bool) -> Signal<[Value], Error> {
		return Signal { observer in
			let state = CollectState<Value>()

			self.observe { event in
				switch event {
				case let .next(value):
					if predicate(values: state.values, next: value) {
						observer.sendNext(state.values)
						state.flush()
					}
					state.append(value)
				case .completed:
					if !state.isEmpty {
						observer.sendNext(state.values)
					}
					observer.sendCompleted()
				case let .failed(error):
					observer.sendFailed(error)
				case .interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}

	/// Forwards all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func observe(on scheduler: SchedulerProtocol) -> Signal<Value, Error> {
		return Signal { observer in
			self.observe { event in
				scheduler.schedule {
					observer.action(event)
				}
			}
		}
	}
}

private final class CombineLatestState<Value> {
	var latestValue: Value?
	var isCompleted = false
}

extension SignalProtocol {
	private func observeWithStates<U>(_ signalState: CombineLatestState<Value>, _ otherState: CombineLatestState<U>, _ lock: Lock, _ observer: Signal<(), Error>.Observer, until trigger: Signal<(), NoError>? = nil) {
		let observer = Observer<Value, Error> { event in
			switch event {
			case let .next(value):
				lock.lock()

				signalState.latestValue = value
				if otherState.latestValue != nil {
					observer.sendNext()
				}

				lock.unlock()

			case let .failed(error):
				observer.sendFailed(error)

			case .completed:
				lock.lock()

				signalState.isCompleted = true
				if otherState.isCompleted {
					observer.sendCompleted()
				}

				lock.unlock()

			case .interrupted:
				observer.sendInterrupted()
			}
		}

		if let trigger = trigger {
			observe(until: trigger, observer: observer)
		} else {
			observe(observer)
		}
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each. If either signal is interrupted, the returned signal
	/// will also be interrupted.
	public func combineLatest<U>(with other: Signal<U, Error>) -> Signal<(Value, U), Error> {
		return Signal { observer in
			let lock = Lock()
			lock.name = "org.reactivecocoa.ReactiveCocoa.combineLatest(with:)"

			let detachment = Signal<(), NoError>.pipe()

			let signalState = CombineLatestState<Value>()
			let otherState = CombineLatestState<U>()

			let observer = Signal<(), Error>.Observer { event in
				switch event {
				case .next:
					observer.sendNext((signalState.latestValue!, otherState.latestValue!))

				case let .failed(error):
					observer.sendFailed(error)
					detachment.observer.sendCompleted()

				case .completed:
					observer.sendCompleted()
					detachment.observer.sendCompleted()

				case .interrupted:
					observer.sendInterrupted()
					detachment.observer.sendCompleted()
				}
			}

			self.observeWithStates(signalState, otherState, lock, observer)
			other.observeWithStates(otherState, signalState, lock, observer, until: detachment.signal)
		}
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Failed` and `Interrupted` events are always scheduled immediately.
	public func delay(_ interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer in
			self.observe { event in
				switch event {
				case .failed, .interrupted:
					scheduler.schedule {
						observer.action(event)
					}

				case .next, .completed:
					let date = scheduler.currentDate.addingTimeInterval(interval)
					scheduler.schedule(after: date) {
						observer.action(event)
					}
				}
			}
		}
	}

	/// Returns a signal that will skip the first `count` values, then forward
	/// everything afterward.
	public func skipFirst(_ count: Int = 1) -> Signal<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return signal
		}

		return Signal { observer in
			var skipped = 0

			self.observe { event in
				if case .next = event where skipped < count {
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
	public func materialize() -> Signal<Event<Value, Error>, NoError> {
		return Signal { observer in
			self.observe { event in
				observer.sendNext(event)

				switch event {
				case .interrupted:
					observer.sendInterrupted()

				case .completed, .failed:
					observer.sendCompleted()

				case .next:
					break
				}
			}
		}
	}
}

extension SignalProtocol where Value: EventProtocol, Error == NoError {
	/// The inverse of materialize(), this will translate a signal of `Event`
	/// _values_ into a signal of those events themselves.
	public func dematerialize() -> Signal<Value.Value, Value.Error> {
		return Signal<Value.Value, Value.Error> { observer in
			self.observe { event in
				switch event {
				case let .next(innerEvent):
					observer.action(innerEvent.event)

				case .failed:
					fatalError("NoError is impossible to construct")

				case .completed:
					observer.sendCompleted()

				case .interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}
}

extension SignalProtocol {
	/// Injects side effects to be performed upon the specified signal events.
	public func on(event: ((Event<Value, Error>) -> Void)? = nil, failed: ((Error) -> Void)? = nil, completed: (() -> Void)? = nil, interrupted: (() -> Void)? = nil, terminated: (() -> Void)? = nil, next: ((Value) -> Void)? = nil) -> Signal<Value, Error> {
		return Signal { observer in
			self.observe { receivedEvent in
				event?(receivedEvent)

				switch receivedEvent {
				case let .next(value):
					next?(value)

				case let .failed(error):
					failed?(error)

				case .completed:
					completed?()

				case .interrupted:
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

private struct SampleState<Value> {
	var latestValue: Value? = nil
	var isSignalCompleted: Bool = false
	var isSamplerCompleted: Bool = false
}

extension SignalProtocol {
	/// Forwards the latest value from `self` with the value from `sampler` as a tuple,
	/// only when`sampler` sends a Next event.
	///
	/// If `sampler` fires before a value has been observed on `self`, nothing
	/// happens.
	///
	/// Returns a signal that will send values from `self` and `sampler`, sampled (possibly
	/// multiple times) by `sampler`, then complete once both input signals have
	/// completed, or interrupt if either input signal is interrupted.
	public func sample<T>(with sampler: Signal<T, NoError>) -> Signal<(Value, T), Error> {
		return Signal { observer in
			let state = Atomic(SampleState<Value>())

			self.observe { event in
				switch event {
				case let .next(value):
					state.modify { st in
						st.latestValue = value
					}
				case let .failed(error):
					observer.sendFailed(error)
				case .completed:
					let oldState = state.modify { st in
						st.isSignalCompleted = true
					}
					
					if oldState.isSamplerCompleted {
						observer.sendCompleted()
					}
				case .interrupted:
					observer.sendInterrupted()
				}
			}
			
			sampler.observe { event in
				switch event {
				case .next(let samplerValue):
					if let value = state.value.latestValue {
						observer.sendNext((value, samplerValue))
					}
				case .completed:
					let oldState = state.modify { st in
						st.isSamplerCompleted = true
					}
					
					if oldState.isSignalCompleted {
						observer.sendCompleted()
					}
				case .interrupted:
					observer.sendInterrupted()
				case .failed:
					break
				}
			}
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
	public func sample(on sampler: Signal<(), NoError>) -> Signal<Value, Error> {
		return sample(with: sampler)
			.map { $0.0 }
	}
	
	/// Does not forward any values from `self` until `trigger` sends a Next or
	/// Completed event, at which point the returned signal behaves exactly like
	/// `signal`.
	public func skipUntil(_ trigger: Signal<(), NoError>) -> Signal<Value, Error> {
		return Signal { observer in
			let detachment = Signal<(), NoError>.pipe()

			trigger.observe(until: detachment.signal) { event in
				switch event {
				case .next, .completed:
					self.observe(observer)
					detachment.observer.sendCompleted()
					
				case .failed, .interrupted:
					break
				}
			}
		}
	}

	/// Forwards events from `self` with history: values of the returned signal
	/// are a tuple whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member when `self`
	/// sends its first value.
	public func combinePrevious(initial: Value) -> Signal<(Value, Value), Error> {
		return scan((initial, initial)) { previousCombinedValues, newValue in
			return (previousCombinedValues.1, newValue)
		}
	}

	/// Like `scan`, but sends only the final value and then immediately completes.
	public func reduce<U>(_ initial: U, _ combine: (U, Value) -> U) -> Signal<U, Error> {
		// We need to handle the special case in which `signal` sends no values.
		// We'll do that by sending `initial` on the output signal (before taking
		// the last value).
		let (scannedSignalWithInitialValue, outputSignalObserver) = Signal<U, Error>.pipe()
		let outputSignal = scannedSignalWithInitialValue.takeLast()

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
	public func scan<U>(_ initial: U, _ combine: (U, Value) -> U) -> Signal<U, Error> {
		return Signal { observer in
			var accumulator = initial

			self.observe { event in
				observer.action(event.map { value in
					accumulator = combine(accumulator, value)
					return accumulator
				})
			}
		}
	}
}

extension SignalProtocol where Value: Equatable {
	/// Forwards only those values from `self` which are not duplicates of the
	/// immedately preceding value. The first value is always forwarded.
	public func skipRepeats() -> Signal<Value, Error> {
		return skipRepeats(==)
	}
}

extension SignalProtocol {
	/// Forwards only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value. The first value is always forwarded.
	public func skipRepeats(_ isRepeat: (Value, Value) -> Bool) -> Signal<Value, Error> {
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
	public func skipWhile(_ predicate: (Value) -> Bool) -> Signal<Value, Error> {
		return Signal { observer in
			var shouldSkip = true

			self.observe { event in
				switch event {
				case let .next(value):
					shouldSkip = shouldSkip && predicate(value)
					if !shouldSkip {
						fallthrough
					}

				case .failed, .completed, .interrupted:
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
	public func takeUntilReplacement(_ replacement: Signal<Value, Error>) -> Signal<Value, Error> {
		return Signal { observer in
			var end = Optional(Signal<(), NoError>.pipe())
			end!.signal.observeCompleted { end = nil }

			self.takeUntil(end!.signal).observe { event in
				switch event {
				case .completed:
					break

				case .next, .failed, .interrupted:
					observer.action(event)
				}
			}

			replacement.observe { event in
				end?.observer.sendCompleted()
				observer.action(event)
			}
		}
	}

	/// Waits until `self` completes and then forwards the final `count` values
	/// on the returned signal.
	public func takeLast(_ count: Int = 1) -> Signal<Value, Error> {
		return Signal { observer in
			var buffer: [Value] = []
			buffer.reserveCapacity(count)

			self.observe { event in
				switch event {
				case let .next(value):
					// To avoid exceeding the reserved capacity of the buffer, we remove then add.
					// Remove elements until we have room to add one more.
					while (buffer.count + 1) > count {
						buffer.remove(at: 0)
					}
					
					buffer.append(value)
				case let .failed(error):
					observer.sendFailed(error)
				case .completed:
					buffer.forEach(observer.sendNext)
					
					observer.sendCompleted()
				case .interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}

	/// Forwards any values from `self` until `predicate` returns false,
	/// at which point the returned signal will complete.
	public func takeWhile(_ predicate: (Value) -> Bool) -> Signal<Value, Error> {
		return Signal { observer in
			self.observe { event in
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

extension SignalProtocol {
	/// Zips elements of two signals into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input signals.
	public func zip<U>(with other: Signal<U, Error>) -> Signal<(Value, U), Error> {
		return Signal { observer in
			let detachment = Signal<(), NoError>.pipe()
			let state = Atomic(ZipState<Value, U>())

			let flush = {
				var tuple: (Value, U)?
				var isFinished = false

				state.modify { state in
					guard !state.values.left.isEmpty && !state.values.right.isEmpty else {
						isFinished = state.isFinished
						return
					}

					tuple = (state.values.left.removeFirst(), state.values.right.removeFirst())
					isFinished = state.isFinished
				}

				if let tuple = tuple {
					observer.sendNext(tuple)
				}

				if isFinished {
					observer.sendCompleted()
					detachment.observer.sendCompleted()
				}
			}
			
			let onFailed = { (error: Error) -> Void in
				observer.sendFailed(error)
				detachment.observer.sendCompleted()
			}

			let onInterrupted = {
				observer.sendInterrupted()
				detachment.observer.sendCompleted()
			}

			self.observe { event in
				switch event {
				case let .next(value):
					state.modify { state in
						state.values.left.append(value)
					}
					
					flush()
				case let .failed(error):
					onFailed(error)
				case .completed:
					state.modify { state in
						state.isCompleted.left = true
					}
					
					flush()
				case .interrupted:
					onInterrupted()
				}
			}

			other.observe(until: detachment.signal) { event in
				switch event {
				case let .next(value):
					state.modify { state in
						state.values.right.append(value)
					}
					
					flush()
				case let .failed(error):
					onFailed(error)
				case .completed:
					state.modify { state in
						state.isCompleted.right = true
					}
					
					flush()
				case .interrupted:
					onInterrupted()
				}
			}
		}
	}

	/// Applies `operation` to values from `self` with `Success`ful results
	/// forwarded on the returned signal and `Failure`s sent as `Failed` events.
	public func attempt(_ operation: (Value) -> Result<(), Error>) -> Signal<Value, Error> {
		return attemptMap { value in
			return operation(value).map {
				return value
			}
		}
	}

	/// Applies `operation` to values from `self` with `Success`ful results mapped
	/// on the returned signal and `Failure`s sent as `Failed` events.
	public func attemptMap<U>(_ operation: (Value) -> Result<U, Error>) -> Signal<U, Error> {
		return Signal { observer in
			self.observe { event in
				switch event {
				case let .next(value):
					operation(value).analysis(
						ifSuccess: observer.sendNext,
						ifFailure: observer.sendFailed
					)
				case let .failed(error):
					observer.sendFailed(error)
				case .completed:
					observer.sendCompleted()
				case .interrupted:
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
	public func throttle(_ interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer in
			let state: Atomic<ThrottleState<Value>> = Atomic(ThrottleState())
			let (disposalTrigger, disposalNotifier) = Signal<(), NoError>.pipe()

			disposalTrigger.observeCompleted {
				var disposable: Disposable?
				state.modify { currentState in
					swap(&disposable, &currentState.schedulerDisposable)
				}
				disposable?.dispose()
			}

			self.observe { event in
				guard let value = event.value else {
					scheduler.schedule {
						observer.action(event)
					}
					disposalNotifier.sendCompleted()
					return
				}

				var scheduleDate: Date!
				state.modify { currentState in
					currentState.pendingValue = value

					let proposedScheduleDate = currentState.previousDate?.addingTimeInterval(interval) ?? scheduler.currentDate
					scheduleDate = (proposedScheduleDate as NSDate).laterDate(scheduler.currentDate)

					currentState.schedulerDisposable = scheduler.schedule(after: scheduleDate) {
						let previousState = state.modify { state in
							if state.pendingValue != nil {
								state.pendingValue = nil
								state.previousDate = scheduleDate
							}
						}

						if let pendingValue = previousState.pendingValue {
							observer.sendNext(pendingValue)
						}
					}
				}
			}
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
	public func debounce(_ interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> Signal<Value, Error> {
		precondition(interval >= 0)
		
		return self
			.materialize()
			.flatMap(.latest) { event -> SignalProducer<Event<Value, Error>, NoError> in
				if event.isTerminating {
					return SignalProducer(value: event).observe(on: scheduler)
				} else {
					return SignalProducer(value: event).delay(interval, on: scheduler)
				}
			}
			.dematerialize()
	}
}

extension SignalProtocol {
	/// Forwards only those values from `self` that have unique identities across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the identities to be retained to check for uniqueness.
	public func uniqueValues<Identity: Hashable>(_ transform: (Value) -> Identity) -> Signal<Value, Error> {
		return Signal { observer in
			var seenValues: Set<Identity> = []
			
			return self
				.observe { event in
					switch event {
					case let .next(value):
						let identity = transform(value)
						if !seenValues.contains(identity) {
							seenValues.insert(identity)
							fallthrough
						}
						
					case .failed, .completed, .interrupted:
						observer.action(event)
					}
				}
		}
	}
}

extension SignalProtocol where Value: Hashable {
	/// Forwards only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// Note: This causes the values to be retained to check for uniqueness. Providing
	/// a function that returns a unique value for each sent value can help you reduce
	/// the memory footprint.
	public func uniqueValues() -> Signal<Value, Error> {
		return uniqueValues { $0 }
	}
}

private struct ThrottleState<Value> {
	var previousDate: Date? = nil
	var pendingValue: Value? = nil
	var schedulerDisposable: Disposable?
}

extension SignalProtocol {
	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>) -> Signal<(Value, B), Error> {
		return a.combineLatest(with: b)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) -> Signal<(Value, B, C), Error> {
		return combineLatest(a, b)
			.combineLatest(with: c)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) -> Signal<(Value, B, C, D), Error> {
		return combineLatest(a, b, c)
			.combineLatest(with: d)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) -> Signal<(Value, B, C, D, E), Error> {
		return combineLatest(a, b, c, d)
			.combineLatest(with: e)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) -> Signal<(Value, B, C, D, E, F), Error> {
		return combineLatest(a, b, c, d, e)
			.combineLatest(with: f)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) -> Signal<(Value, B, C, D, E, F, G), Error> {
		return combineLatest(a, b, c, d, e, f)
			.combineLatest(with: g)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G, H>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) -> Signal<(Value, B, C, D, E, F, G, H), Error> {
		return combineLatest(a, b, c, d, e, f, g)
			.combineLatest(with: h)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G, H, I>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I), Error> {
		return combineLatest(a, b, c, d, e, f, g, h)
			.combineLatest(with: i)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G, H, I, J>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I, J), Error> {
		return combineLatest(a, b, c, d, e, f, g, h, i)
			.combineLatest(with: j)
			.map(repack)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatestWith`. No events will be sent if the sequence is empty.
	public static func combineLatest<S: Sequence where S.Iterator.Element == Signal<Value, Error>>(_ signals: S) -> Signal<[Value], Error> {
		var generator = signals.makeIterator()
		if let first = generator.next() {
			let initial = first.map { [$0] }
			return IteratorSequence(generator).reduce(initial) { signal, next in
				signal.combineLatest(with: next).map { $0.0 + [$0.1] }
			}
		}
		
		return .never
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>) -> Signal<(Value, B), Error> {
		return a.zip(with: b)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) -> Signal<(Value, B, C), Error> {
		return zip(a, b)
			.zip(with: c)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) -> Signal<(Value, B, C, D), Error> {
		return zip(a, b, c)
			.zip(with: d)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) -> Signal<(Value, B, C, D, E), Error> {
		return zip(a, b, c, d)
			.zip(with: e)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) -> Signal<(Value, B, C, D, E, F), Error> {
		return zip(a, b, c, d, e)
			.zip(with: f)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) -> Signal<(Value, B, C, D, E, F, G), Error> {
		return zip(a, b, c, d, e, f)
			.zip(with: g)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G, H>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) -> Signal<(Value, B, C, D, E, F, G, H), Error> {
		return zip(a, b, c, d, e, f, g)
			.zip(with: h)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G, H, I>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I), Error> {
		return zip(a, b, c, d, e, f, g, h)
			.zip(with: i)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G, H, I, J>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I, J), Error> {
		return zip(a, b, c, d, e, f, g, h, i)
			.zip(with: j)
			.map(repack)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zipWith`. No events will be sent if the sequence is empty.
	public static func zip<S: Sequence where S.Iterator.Element == Signal<Value, Error>>(_ signals: S) -> Signal<[Value], Error> {
		var generator = signals.makeIterator()
		if let first = generator.next() {
			let initial = first.map { [$0] }
			return IteratorSequence(generator).reduce(initial) { signal, next in
				signal.zip(with: next).map { $0.0 + [$0.1] }
			}
		}
		
		return .never
	}
}

extension SignalProtocol {
	/// Forwards events from `self` until `interval`. Then if signal isn't completed yet,
	/// fails with `error` on `scheduler`.
	///
	/// If the interval is 0, the timeout will be scheduled immediately. The signal
	/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
	public func timeout(failingWith error: Error, after interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer in
			let (disposalTrigger, disposalNotifier) = Signal<(), NoError>.pipe()

			let date = scheduler.currentDate.addingTimeInterval(interval)

			let schedulerDisposable = scheduler.schedule(after: date) {
				observer.sendFailed(error)
				disposalNotifier.sendCompleted()
			}

			disposalTrigger.observeCompleted {
				schedulerDisposable?.dispose()
			}

			self.observe(observer.completingOnTermination(disposalNotifier))
		}
	}
}

extension SignalProtocol where Error == NoError {
	/// Promotes a signal that does not generate failures into one that can.
	///
	/// This does not actually cause failures to be generated for the given signal,
	/// but makes it easier to combine with other signals that may fail; for
	/// example, with operators like `combineLatestWith`, `zipWith`, `flatten`, etc.
	public func promoteErrors<F: ErrorProtocol>(_: F.Type) -> Signal<Value, F> {
		return Signal { observer in
			self.observe { event in
				switch event {
				case let .next(value):
					observer.sendNext(value)
				case .failed:
					fatalError("NoError is impossible to construct")
				case .completed:
					observer.sendCompleted()
				case .interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}
}

extension ObserverType {
	public func completingOnTermination<T, U: ErrorProtocol>(_ observer: Signal<T, U>.Observer) -> Observer<Value, Error> {
		return Observer { event in
			self.action(event)

			switch event {
			case .failed, .completed, .interrupted:
				observer.sendCompleted()
			case .next:
				break
			}
		}
	}
}
