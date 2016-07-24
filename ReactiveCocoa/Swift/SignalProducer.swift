import Foundation
import Result

/// A SignalProducer creates Signals that can produce values of type `Value` 
/// and/or fail with errors of type `Error`. If no failure should be possible, 
/// `NoError` can be specified for `Error`.
///
/// SignalProducers can be used to represent operations or tasks, like network
/// requests, where each invocation of `start()` will create a new underlying
/// operation. This ensures that consumers will receive the results, versus a
/// plain Signal, where the results might be sent before any observers are
/// attached.
///
/// Because of the behavior of `start()`, different Signals created from the
/// producer may see a different version of Events. The Events may arrive in a
/// different order between Signals, or the stream might be completely
/// different!
public struct SignalProducer<Value, Error: ErrorProtocol> {
	public typealias ProducedSignal = Signal<Value, Error>

	private let startHandler: (Signal<Value, Error>.Observer, CompositeDisposable) -> Void

	/// Initializes a `SignalProducer` that will emit the same events as the
	/// given signal.
	///
	/// If the Disposable returned from `start()` is disposed or a terminating
	/// event is sent to the observer, the given signal will be disposed.
	///
	/// - parameters:
	///   - signal: A signal to observe after starting the producer.
	public init<S: SignalProtocol where S.Value == Value, S.Error == Error>(signal: S) {
		self.init { observer, disposable in
			disposable += signal.observe(observer)
		}
	}

	/// Initializes a SignalProducer that will invoke the given closure once for
	/// each invocation of `start()`.
	///
	/// The events that the closure puts into the given observer will become
	/// the events sent by the started `Signal` to its observers.
	///
	/// - note: If the `Disposable` returned from `start()` is disposed or a
	///         terminating event is sent to the observer, the given
	///         `CompositeDisposable` will be disposed, at which point work
	///         should be interrupted and any temporary resources cleaned up.
	///
	/// - parameters:
	///   - startHandler: A closure that accepts observer and a disposable.
	public init(_ startHandler: (Signal<Value, Error>.Observer, CompositeDisposable) -> Void) {
		self.startHandler = startHandler
	}

	/// Creates a producer for a `Signal` that will immediately send one value
	/// then complete.
	///
	/// - parameters:
	///   - value: A value that should be sent by the `Signal` in a `next`
	///            event.
	public init(value: Value) {
		self.init { observer, disposable in
			observer.sendNext(value)
			observer.sendCompleted()
		}
	}

	/// Creates a producer for a `Signal` that will immediately fail with the
	/// given error.
	///
	/// - parameters:
	///   - error: An error that should be sent by the `Signal` in a `failed`
	///            event.
	public init(error: Error) {
		self.init { observer, disposable in
			observer.sendFailed(error)
		}
	}

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete, or immediately fail, depending on the given Result.
	///
	/// - parameters:
	///   - result: A `Result` instance that will send either `next` event if
	///             `result` is `Success`ful or `failed` event if `result` is a
	///             `Failure`.
	public init(result: Result<Value, Error>) {
		switch result {
		case let .success(value):
			self.init(value: value)

		case let .failure(error):
			self.init(error: error)
		}
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	///
	/// - parameters:
	///   - values: A sequence of values that a `Signal` will send as separate
	///             `next` events and then complete.
	public init<S: Sequence where S.Iterator.Element == Value>(values: S) {
		self.init { observer, disposable in
			for value in values {
				observer.sendNext(value)

				if disposable.isDisposed {
					break
				}
			}

			observer.sendCompleted()
		}
	}
	
	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	///
	/// - parameters:
	///   - first: First value for the `Signal` to send.
	///   - second: Second value for the `Signal` to send.
	///   - tail: Rest of the values to be sent by the `Signal`.
	public init(values first: Value, _ second: Value, _ tail: Value...) {
		self.init(values: [ first, second ] + tail)
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

	/// Create a `SignalProducer` that will attempt the given operation once for
	/// each invocation of `start()`.
	///
	/// Upon success, the started signal will send the resulting value then
	/// complete. Upon failure, the started signal will fail with the error that
	/// occurred.
	///
	/// - parameters:
	///   - operation: A closure that returns instance of `Result`.
	///
	/// - returns: A `SignalProducer` that will forward `Success`ful `result` as
	///            `next` event and then complete or `failed` event if `result`
	///            is a `Failure`.
	public static func attempt(_ operation: () -> Result<Value, Error>) -> SignalProducer {
		return self.init { observer, disposable in
			operation().analysis(ifSuccess: { value in
				observer.sendNext(value)
				observer.sendCompleted()
				}, ifFailure: { error in
					observer.sendFailed(error)
			})
		}
	}

	/// Create a Signal from the producer, pass it into the given closure,
	/// then start sending events on the Signal when the closure has returned.
	///
	/// The closure will also receive a disposable which can be used to
	/// interrupt the work associated with the signal and immediately send an
	/// `interrupted` event.
	///
	/// - parameters:
	///   - setUp: A closure that accepts a `signal` and `interrupter`.
	public func startWithSignal(_ setup: @noescape (signal: Signal<Value, Error>, interrupter: Disposable) -> Void) {
		let (signal, observer) = Signal<Value, Error>.pipe()

		// Disposes of the work associated with the SignalProducer and any
		// upstream producers.
		let producerDisposable = CompositeDisposable()

		// Directly disposed of when `start()` or `startWithSignal()` is
		// disposed.
		let cancelDisposable = ActionDisposable {
			observer.sendInterrupted()
			producerDisposable.dispose()
		}

		setup(signal: signal, interrupter: cancelDisposable)

		if cancelDisposable.isDisposed {
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

public protocol SignalProducerProtocol {
	/// The type of values being sent on the producer
	associatedtype Value
	/// The type of error that can occur on the producer. If errors aren't possible
	/// then `NoError` can be used.
	associatedtype Error: ErrorProtocol

	/// Extracts a signal producer from the receiver.
	var producer: SignalProducer<Value, Error> { get }

	/// Initialize a signal
	init(_ startHandler: (Signal<Value, Error>.Observer, CompositeDisposable) -> Void)

	/// Creates a Signal from the producer, passes it into the given closure,
	/// then starts sending events on the Signal when the closure has returned.
	func startWithSignal(_ setup: @noescape (signal: Signal<Value, Error>, interrupter: Disposable) -> Void)
}

extension SignalProducer: SignalProducerProtocol {
	public var producer: SignalProducer {
		return self
	}
}

extension SignalProducerProtocol {
	/// Create a Signal from the producer, then attach the given observer to
	/// the `Signal` as an observer.
	///
	/// - parameters:
	///   - observer: An observer to attach to produced signal.
	///
	/// - returns: A `Disposable` which can be used to interrupt the work
	///            associated with the signal and immediately send an
	///            `interrupted` event.
	@discardableResult
	public func start(_ observer: Signal<Value, Error>.Observer = Signal<Value, Error>.Observer()) -> Disposable {
		var disposable: Disposable!

		startWithSignal { signal, innerDisposable in
			signal.observe(observer)
			disposable = innerDisposable
		}

		return disposable
	}

	/// Convenience override for start(_:) to allow trailing-closure style
	/// invocations.
	///
	/// - parameters:
	///   - observerAction: A closure that accepts `Event` sent by the produced
	///                     signal.
	///
	/// - returns: A `Disposable` which can be used to interrupt the work
	///            associated with the signal and immediately send an
	///            `interrupted` event.
	@discardableResult
	public func start(_ observerAction: Signal<Value, Error>.Observer.Action) -> Disposable {
		return start(Observer(observerAction))
	}

	/// Create a Signal from the producer, then add an observer to the `Signal`,
	/// which will invoke the given callback when `next` or `failed` events are
	/// received.
	///
	/// - parameters:
	///   - result: A closure that accepts a `result` that contains a `Success`
	///             case for `next` events or `Failure` case for `failed` event.
	///
	/// - returns:  A Disposable which can be used to interrupt the work
	///             associated with the Signal, and prevent any future callbacks
	///             from being invoked.
	@discardableResult
	public func startWithResult(_ result: (Result<Value, Error>) -> Void) -> Disposable {
		return start(
			Observer(
				next: { result(.success($0)) },
				failed: { result(.failure($0)) }
			)
		)
	}

	/// Create a Signal from the producer, then add exactly one observer to the
	/// Signal, which will invoke the given callback when a `completed` event is
	/// received.
	///
	/// - parameters:
	///   - completed: A closure that will be envoked when produced signal sends
	///                `completed` event.
	///
	/// - returns: A `Disposable` which can be used to interrupt the work
	///            associated with the signal.
	@discardableResult
	public func startWithCompleted(_ completed: () -> Void) -> Disposable {
		return start(Observer(completed: completed))
	}
	
	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callback when a `failed` event
	/// is received.
	///
	/// - parameters:
	///   - failed: A closure that accepts an error object.
	///
	/// - returns: A `Disposable` which can be used to interrupt the work
	///            associated with the signal.
	@discardableResult
	public func startWithFailed(_ failed: (Error) -> Void) -> Disposable {
		return start(Observer(failed: failed))
	}
	
	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callback when an `interrupted`
	/// event is received.
	///
	/// - parameters:
	///   - interrupted: A closure that is invoked when `interrupted` event is
	///                  received.
	///
	/// - returns: A `Disposable` which can be used to interrupt the work
	///            associated with the signal.
	@discardableResult
	public func startWithInterrupted(_ interrupted: () -> Void) -> Disposable {
		return start(Observer(interrupted: interrupted))
	}
}

extension SignalProducerProtocol where Error == NoError {
	/// Create a Signal from the producer, then add exactly one observer to
	/// the Signal, which will invoke the given callback when `next` events are
	/// received.
	///
	/// - parameters:
	///   - next: A closure that accepts a value carried by `next` event.
	///
	/// - returns: A `Disposable` which can be used to interrupt the work
	///            associated with the Signal, and prevent any future callbacks
	///            from being invoked.
	@discardableResult
	public func startWithNext(_ next: (Value) -> Void) -> Disposable {
		return start(Observer(next: next))
	}
}

extension SignalProducerProtocol {
	/// Lift an unary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new `SignalProducer` which will apply
	/// the given `Signal` operator to _every_ created `Signal`, just as if the
	/// operator had been applied to each `Signal` yielded from `start()`.
	///
	/// - parameters:
	///   - transform: An unary operator to lift.
	///
	/// - returns: A signal producer that applies signal's operator to every
	///            created signal.
	public func lift<U, F>(_ transform: (Signal<Value, Error>) -> Signal<U, F>) -> SignalProducer<U, F> {
		return SignalProducer { observer, outerDisposable in
			self.startWithSignal { signal, innerDisposable in
				outerDisposable += innerDisposable

				transform(signal).observe(observer)
			}
		}
	}
	

	/// Lift a binary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new `SignalProducer` which will apply
	/// the given `Signal` operator to _every_ `Signal` created from the two
	/// producers, just as if the operator had been applied to each `Signal`
	/// yielded from `start()`.
	///
	/// - note: starting the returned producer will start the receiver of the
	///         operator, which may not be adviseable for some operators.
	///
	/// - parameters:
	///   - transform: A binary operator to lift.
	///
	/// - returns: A binary operator that operates on two signal producers.
	public func lift<U, F, V, G>(_ transform: (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (SignalProducer<U, F>) -> SignalProducer<V, G> {
		return liftRight(transform)
	}

	/// Right-associative lifting of a binary signal operator over producers.
	/// That is, the argument producer will be started before the receiver. When
	/// both producers are synchronous this order can be important depending on
	/// the operator to generate correct results.
	private func liftRight<U, F, V, G>(_ transform: (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (SignalProducer<U, F>) -> SignalProducer<V, G> {
		return { otherProducer in
			return SignalProducer { observer, outerDisposable in
				self.startWithSignal { signal, disposable in
					outerDisposable.add(disposable)

					otherProducer.startWithSignal { otherSignal, otherDisposable in
						outerDisposable += otherDisposable

						transform(signal)(otherSignal).observe(observer)
					}
				}
			}
		}
	}

	/// Left-associative lifting of a binary signal operator over producers.
	/// That is, the receiver will be started before the argument producer. When
	/// both producers are synchronous this order can be important depending on
	/// the operator to generate correct results.
	private func liftLeft<U, F, V, G>(_ transform: (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (SignalProducer<U, F>) -> SignalProducer<V, G> {
		return { otherProducer in
			return SignalProducer { observer, outerDisposable in
				otherProducer.startWithSignal { otherSignal, otherDisposable in
					outerDisposable += otherDisposable
					
					self.startWithSignal { signal, disposable in
						outerDisposable.add(disposable)

						transform(signal)(otherSignal).observe(observer)
					}
				}
			}
		}
	}
	

	/// Lift a binary Signal operator to operate upon a Signal and a
	/// SignalProducer instead.
	///
	/// In other words, this will create a new `SignalProducer` which will apply
	/// the given `Signal` operator to _every_ `Signal` created from the two
	/// producers, just as if the operator had been applied to each `Signal`
	/// yielded from `start()`.
	///
	/// - parameters:
	///   - transform: A binary operator to lift.
	///
	/// - returns: A binary operator that works on `Signal` and returns
	///            `SignalProducer`.
	public func lift<U, F, V, G>(_ transform: (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (Signal<U, F>) -> SignalProducer<V, G> {
		return { otherSignal in
			return SignalProducer { observer, outerDisposable in
				let (wrapperSignal, otherSignalObserver) = Signal<U, F>.pipe()

				// Avoid memory leak caused by the direct use of the given
				// signal.
				//
				// See https://github.com/ReactiveCocoa/ReactiveCocoa/pull/2758
				// for the details.
				outerDisposable += ActionDisposable {
					otherSignalObserver.sendInterrupted()
				}
				outerDisposable += otherSignal.observe(otherSignalObserver)

				self.startWithSignal { signal, disposable in
					outerDisposable += disposable
					outerDisposable += transform(signal)(wrapperSignal).observe(observer)
				}
			}
		}
	}
	

	/// Map each value in the producer to a new value.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value and returns a different
	///                value.
	///
	/// - returns: A signal producer that, when started, will send a mapped
	///            value of `self.`
	public func map<U>(_ transform: (Value) -> U) -> SignalProducer<U, Error> {
		return lift { $0.map(transform) }
	}

	/// Map errors in the producer to a new error.
	///
	/// - parameters:
	///   - transform: A closure that accepts an error object and returns a
	///                different error.
	///
	/// - returns: A producer that emits errors of new type.
	public func mapError<F>(_ transform: (Error) -> F) -> SignalProducer<Value, F> {
		return lift { $0.mapError(transform) }
	}

	/// Preserve only the values of the producer that pass the given predicate.
	///
	/// - parameters:
	///   - predicate: A closure that accepts value and returns `Bool` denoting
	///                whether value has passed the test.
	///
	/// - returns: A producer that, when started, will send only the values
	///            passing the given predicate.
	public func filter(_ predicate: (Value) -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.filter(predicate) }
	}

	/// Yield the first `count` values from the input producer.
	///
	/// - precondition: `count` must be non-negative number.
	///
	/// - parameters:
	///   - count: A number of values to take from the signal.
	///
	/// - returns: A producer that, when started, will yield the first `count`
	///            values from `self`.
	public func take(first count: Int) -> SignalProducer<Value, Error> {
		return lift { $0.take(first: count) }
	}

	/// Yield an array of values when `self` completes.
	///
	/// - note: When `self` completes without collecting any value, it will send
	///         an empty array of values.
	///
	/// - returns: A producer that, when started, will yield an array of values
	///            when `self` completes.
	public func collect() -> SignalProducer<[Value], Error> {
		return lift { $0.collect() }
	}

	/// Yield an array of values until it reaches a certain count.
	///
	/// - precondition: `count` should be greater than zero.
	///
	/// - note: When the count is reached the array is sent and the signal
	///         starts over yielding a new array of values.
	///
	/// - note: When `self` completes any remaining values will be sent, the
	///         last array may not have `count` values. Alternatively, if were
	///         not collected any values will sent an empty array of values.
	///
	/// - returns: A producer that, when started, collects at most `count`
	///            values from `self`, forwards them as a single array and
	///            completes.
	public func collect(count: Int) -> SignalProducer<[Value], Error> {
		precondition(count > 0)
		return lift { $0.collect(count: count) }
	}

	/// Yield an array of values based on a predicate which matches the values
	/// collected.
	///
	/// - note: When `self` completes any remaining values will be sent, the
	///         last array may not match `predicate`. Alternatively, if were not
	///         collected any values will sent an empty array of values.
	///
	/// ````
	/// let (producer, observer) = SignalProducer<Int, NoError>.buffer(1)
	///
	/// producer
	///     .collect { values in values.reduce(0, combine: +) == 8 }
	///     .startWithNext { print($0) }
	///
	/// observer.sendNext(1)
	/// observer.sendNext(3)
	/// observer.sendNext(4)
	/// observer.sendNext(7)
	/// observer.sendNext(1)
	/// observer.sendNext(5)
	/// observer.sendNext(6)
	/// observer.sendCompleted()
	///
	/// // Output:
	/// // [1, 3, 4]
	/// // [7, 1]
	/// // [5, 6]
	/// ````
	///
	/// - parameters:
	///   - predicate: Predicate to match when values should be sent (returning
	///                `true`) or alternatively when they should be collected
	///                (where it should return `false`). The most recent value
	///                (`next`) is included in `values` and will be the end of
	///                the current array of values if the predicate returns
	///                `true`.
	///
	/// - returns: A producer that, when started, collects values passing the
	///            predicate and, when `self` completes, forwards them as a
	///            single array and complets.
	public func collect(_ predicate: (values: [Value]) -> Bool) -> SignalProducer<[Value], Error> {
		return lift { $0.collect(predicate) }
	}

	/// Yield an array of values based on a predicate which matches the values
	/// collected and the next value.
	///
	/// - note: When `self` completes any remaining values will be sent, the
	///         last array may not match `predicate`. Alternatively, if no
	///         values were collected an empty array will be sent.
	///
	/// ````
	/// let (producer, observer) = SignalProducer<Int, NoError>.buffer(1)
	///
	/// producer
	///     .collect { values, next in next == 7 }
	///     .startWithNext { print($0) }
	///
	/// observer.sendNext(1)
	/// observer.sendNext(1)
	/// observer.sendNext(7)
	/// observer.sendNext(7)
	/// observer.sendNext(5)
	/// observer.sendNext(6)
	/// observer.sendCompleted()
	///
	/// // Output:
	/// // [1, 1]
	/// // [7]
	/// // [7, 5, 6]
	/// ````
	///
	/// - parameters:
	///   - predicate: Predicate to match when values should be sent (returning
	///                `true`) or alternatively when they should be collected
	///                (where it should return `false`). The most recent value
	///                (`next`) is not included in `values` and will be the
	///                start of the next array of values if the predicate
	///                returns `true`.
	///
	/// - returns: A signal that will yield an array of values based on a
	///            predicate which matches the values collected and the next
	///            value.
	public func collect(_ predicate: (values: [Value], next: Value) -> Bool) -> SignalProducer<[Value], Error> {
		return lift { $0.collect(predicate) }
	}

	/// Forward all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	///
	/// - parameters:
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that, when started, will yield `self` values on
	///            provided scheduler.
	public func observe(on scheduler: SchedulerProtocol) -> SignalProducer<Value, Error> {
		return lift { $0.observe(on: scheduler) }
	}

	/// Combine the latest value of the receiver with the latest value from the
	/// given producer.
	///
	/// - note: The returned producer will not send a value until both inputs
	///         have sent at least one value each. 
	///
	/// - note: If either producer is interrupted, the returned producer will
	///         also be interrupted.
	///
	/// - parameters:
	///   - other: A producer to combine `self`'s value with.
	///
	/// - returns: A producer that, when started, will yield a tuple containing
	///            values of `self` and given producer.
	public func combineLatest<U>(with other: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> {
		// This should be the implementation of this method:
		// return liftRight(Signal.combineLatestWith)(otherProducer)
		//
		// However, due to a Swift miscompilation (with `-O`) we need to inline `liftRight` here.
		// See https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2751 for more details.
		//
		// This can be reverted once tests with -O don't crash. 

		return SignalProducer { observer, outerDisposable in
			self.startWithSignal { signal, disposable in
				outerDisposable.add(disposable)

				other.startWithSignal { otherSignal, otherDisposable in
					outerDisposable += otherDisposable

					signal.combineLatest(with: otherSignal).observe(observer)
				}
			}
		}
	}

	/// Combine the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// - note: The returned producer will not send a value until both inputs
	///         have sent at least one value each. 
	///
	/// - note: If either input is interrupted, the returned producer will also
	///         be interrupted.
	///
	/// - parameters:
	///   - other: A signal to combine `self`'s value with.
	///
	/// - returns: A producer that, when started, will yield a tuple containing
	///            values of `self` and given signal.
	public func combineLatest<U>(with other: Signal<U, Error>) -> SignalProducer<(Value, U), Error> {
		return lift(Signal.combineLatest(with:))(other)
	}

	/// Delay `next` and `completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// - note: `failed` and `interrupted` events are always scheduled
	///         immediately.
	///
	/// - parameters:
	///   - interval: Interval to delay `next` and `completed` events by.
	///   - scheduler: A scheduler to deliver delayed events on.
	///
	/// - returns: A producer that, when started, will delay `next` and
	///            `completed` events and will yield them on given scheduler.
	public func delay(_ interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
		return lift { $0.delay(interval, on: scheduler) }
	}

	/// Skip the first `count` values, then forward everything afterward.
	///
	/// - parameters:
	///   - count: A number of values to skip.
	///
	/// - returns:  A producer that, when started, will skip the first `count`
	///             values, then forward everything afterward.
	public func skip(first count: Int) -> SignalProducer<Value, Error> {
		return lift { $0.skip(first: count) }
	}

	/// Treats all Events from the input producer as plain values, allowing them
	/// to be manipulated just like any other value.
	///
	/// In other words, this brings Events “into the monad.”
	///
	/// - note: When a Completed or Failed event is received, the resulting
	///         producer will send the Event itself and then complete. When an
	///         `interrupted` event is received, the resulting producer will
	///         send the `Event` itself and then interrupt.
	///
	/// - returns: A producer that sends events as its values.
	public func materialize() -> SignalProducer<Event<Value, Error>, NoError> {
		return lift { $0.materialize() }
	}

	/// Forward the latest value from `self` with the value from `sampler` as a
	/// tuple, only when `sampler` sends a `next` event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A producer that will trigger the delivery of `next` event
	///              from `self`.
	///
	/// - returns: A producer that will send values from `self` and `sampler`,
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input producers have completed, or interrupt if
	///            either input producer is interrupted.
	public func sample<T>(with sampler: SignalProducer<T, NoError>) -> SignalProducer<(Value, T), Error> {
		return liftLeft(Signal.sample(with:))(sampler)
	}
	
	/// Forward the latest value from `self` with the value from `sampler` as a
	/// tuple, only when `sampler` sends a `next` event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A signal that will trigger the delivery of `next` event
	///              from `self`.
	///
	/// - returns: A producer that, when started, will send values from `self`
	///            and `sampler`, sampled (possibly multiple times) by
	///            `sampler`, then complete once both input producers have
	///            completed, or interrupt if either input producer is
	///            interrupted.
	public func sample<T>(with sampler: Signal<T, NoError>) -> SignalProducer<(Value, T), Error> {
		return lift(Signal.sample(with:))(sampler)
	}

	/// Forward the latest value from `self` whenever `sampler` sends a `next`
	/// event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A producer that will trigger the delivery of `next` event
	///              from `self`.
	///
	/// - returns: A producer that, when started, will send values from `self`,
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input producers have completed, or interrupt if
	///            either input producer is interrupted.
	public func sample(on sampler: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> {
		return liftLeft(Signal.sample(on:))(sampler)
	}

	/// Forward the latest value from `self` whenever `sampler` sends a `next`
	/// event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - trigger: A signal whose `next` or `completed` events will start the
	///              deliver of events on `self`.
	///
	/// - returns: A producer that will send values from `self`, sampled
	///            (possibly multiple times) by `sampler`, then complete once 
	///            both inputs have completed, or interrupt if either input is
	///            interrupted.
	public func sample(on sampler: Signal<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.sample(on:))(sampler)
	}

	/// Forward events from `self` until the lifetime producer of `object`
	/// completes, at which point the returned producer will complete.
	///
	/// - parameters:
	///   - object: A `LifetimeProviding` object.
	///
	/// - returns: A producer that will deliver events until the lifetime producer
	///            of `object` completes.
	public func take<U: LifetimeProviding>(withinLifetimeOf object: U) -> SignalProducer<Value, Error> {
		return take(until: object.lifetimeProducer)
	}

	/// Forward events from `self` until `trigger` sends a `next` or `completed`
	/// event, at which point the returned producer will complete.
	///
	/// - parameters:
	///   - trigger: A producer whose `next` or `completed` events will stop the
	///              delivery of `next` events from `self`.
	///
	/// - returns: A producer that will deliver events until `trigger` sends
	///            `next` or `completed` events.
	public func take(until trigger: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> {
		// This should be the implementation of this method:
		// return liftRight(Signal.takeUntil)(trigger)
		//
		// However, due to a Swift miscompilation (with `-O`) we need to inline
		// `liftRight` here.
		//
		// See https://github.com/ReactiveCocoa/ReactiveCocoa/issues/2751 for
		// more details.
		//
		// This can be reverted once tests with -O work correctly.
		return SignalProducer { observer, outerDisposable in
			self.startWithSignal { signal, disposable in
				outerDisposable.add(disposable)

				trigger.startWithSignal { triggerSignal, triggerDisposable in
					outerDisposable += triggerDisposable

					signal.take(until: triggerSignal).observe(observer)
				}
			}
		}
	}

	/// Forward events from `self` until `trigger` sends a Next or Completed
	/// event, at which point the returned producer will complete.
	///
	/// - parameters:
	///   - trigger: A signal whose `next` or `completed` events will stop the
	///              delivery of `next` events from `self`.
	///
	/// - returns: A producer that will deliver events until `trigger` sends
	///            `next` or `completed` events.
	public func take(until trigger: Signal<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.take(until:))(trigger)
	}

	/// Do not forward any values from `self` until `trigger` sends a `next`
	/// or `completed`, at which point the returned producer behaves exactly
	/// like `producer`.
	///
	/// - parameters:
	///   - trigger: A producer whose `next` or `completed` events will start
	///              the deliver of events on `self`.
	///
	/// - returns: A producer that will deliver events once the `trigger` sends
	///            `next` or `completed` events.
	public func skip(until trigger: SignalProducer<(), NoError>) -> SignalProducer<Value, Error> {
		return liftRight(Signal.skip(until:))(trigger)
	}
	
	/// Do not forward any values from `self` until `trigger` sends a `next`
	/// or `completed`, at which point the returned signal behaves exactly like
	/// `signal`.
	///
	/// - parameters:
	///   - trigger: A signal whose `next` or `completed` events will start the
	///              deliver of events on `self`.
	///
	/// - returns: A producer that will deliver events once the `trigger` sends
	///            `next` or `completed` events.
	public func skip(until trigger: Signal<(), NoError>) -> SignalProducer<Value, Error> {
		return lift(Signal.skip(until:))(trigger)
	}
	
	/// Forward events from `self` with history: values of the returned producer
	/// are a tuple whose first member is the previous value and whose second
	/// member is the current value. `initial` is supplied as the first member
	/// when `self` sends its first value.
	///
	/// - parameters:
	///   - initial: A value that will be combined with the first value sent by
	///              `self`.
	///
	/// - returns: A producer that sends tuples that contain previous and
	///            current sent values of `self`.
	public func combinePrevious(_ initial: Value) -> SignalProducer<(Value, Value), Error> {
		return lift { $0.combinePrevious(initial) }
	}

	/// Send only the final value and then immediately completes.
	///
	/// - parameters:
	///   - initial: Initial value for the accumulator.
	///   - combine: A closure that accepts accumulator and sent value of
	///              `self`.
	///
	/// - returns: A producer that sends accumulated value after `self`
	///             completes.
	public func reduce<U>(_ initial: U, _ combine: (U, Value) -> U) -> SignalProducer<U, Error> {
		return lift { $0.reduce(initial, combine) }
	}

	/// Aggregate `self`'s values into a single combined value. When `self`
	/// emits its first value, `combine` is invoked with `initial` as the first
	/// argument and that emitted value as the second argument. The result is
	/// emitted from the producer returned from `scan`. That result is then
	/// passed to `combine` as the first argument when the next value is
	/// emitted, and so on.
	///
	/// - parameters:
	///   - initial: Initial value for the accumulator.
	///   - combine: A closure that accepts accumulator and sent value of
	///              `self`.
	///
	/// - returns: A producer that sends accumulated value each time `self`
	///            emits own value.
	public func scan<U>(_ initial: U, _ combine: (U, Value) -> U) -> SignalProducer<U, Error> {
		return lift { $0.scan(initial, combine) }
	}

	/// Forward only those values from `self` which do not pass `isRepeat` with
	/// respect to the previous value.
	///
	/// - note: The first value is always forwarded.
	///
	/// - returns: A producer that does not send two equal values sequentially.
	public func skipRepeats(_ isRepeat: (Value, Value) -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.skipRepeats(isRepeat) }
	}

	/// Do not forward any values from `self` until `predicate` returns false,
	/// at which point the returned producer behaves exactly like `self`.
	///
	/// - parameters:
	///   - predicate: A closure that accepts a value and returns whether `self`
	///                should still not forward that value to a `producer`.
	///
	/// - returns: A producer that sends only forwarded values from `self`.
	public func skip(while predicate: (Value) -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.skip(while: predicate) }
	}

	/// Forward events from `self` until `replacement` begins sending events.
	///
	/// - parameters:
	///   - replacement: A producer to wait to wait for values from and start
	///                  sending them as a replacement to `self`'s values.
	///
	/// - returns: A producer which passes through `next`, `failed`, and
	///            `interrupted` events from `self` until `replacement` sends an 
	///            event, at which point the returned producer will send that
	///            event and switch to passing through events from `replacement` 
	///            instead, regardless of whether `self` has sent events
	///            already.
	public func take(untilReplacement signal: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return liftRight(Signal.take(untilReplacement:))(signal)
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// - parameters:
	///   - replacement: A signal to wait to wait for values from and start
	///                  sending them as a replacement to `self`'s values.
	///
	/// - returns: A producer which passes through `next`, `failed`, and
	///            `interrupted` events from `self` until `replacement` sends an
	///            event, at which point the returned producer will send that
	///            event and switch to passing through events from `replacement`
	///            instead, regardless of whether `self` has sent events
	///            already.
	public func take(untilReplacement signal: Signal<Value, Error>) -> SignalProducer<Value, Error> {
		return lift(Signal.take(untilReplacement:))(signal)
	}

	/// Wait until `self` completes and then forward the final `count` values
	/// on the returned producer.
	///
	/// - parameters:
	///   - count: Number of last events to send after `self` completes.
	///
	/// - returns: A producer that receives up to `count` values from `self`
	///            after `self` completes.
	public func take(last count: Int) -> SignalProducer<Value, Error> {
		return lift { $0.take(last: count) }
	}

	/// Forward any values from `self` until `predicate` returns false, at which
	/// point the returned producer will complete.
	///
	/// - parameters:
	///   - predicate: A closure that accepts value and returns `Bool` value
	///                whether `self` should forward it to `signal` and continue
	///                sending other events.
	///
	/// - returns: A producer that sends events until the values sent by `self`
	///            pass the given `predicate`.
	public func take(while predicate: (Value) -> Bool) -> SignalProducer<Value, Error> {
		return lift { $0.take(while: predicate) }
	}

	/// Zip elements of two producers into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input producers.
	///
	/// - parameters:
	///   - other: A producer to zip values with.
	///
	/// - returns: A producer that sends tuples of `self` and `otherProducer`.
	public func zip<U>(with other: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> {
		return liftRight(Signal.zip(with:))(other)
	}

	/// Zip elements of this producer and a signal into pairs. The elements of
	/// any Nth pair are the Nth elements of the two.
	///
	/// - parameters:
	///   - other: A signal to zip values with.
	///
	/// - returns: A producer that sends tuples of `self` and `otherSignal`.
	public func zip<U>(with other: Signal<U, Error>) -> SignalProducer<(Value, U), Error> {
		return lift(Signal.zip(with:))(other)
	}

	/// Apply `operation` to values from `self` with `Success`ful results
	/// forwarded on the returned producer and `Failure`s sent as `failed`
	/// events.
	///
	/// - parameters:
	///   - operation: A closure that accepts a value and returns a `Result`.
	///
	/// - returns: A producer that receives `Success`ful `Result` as `next`
	///            event and `Failure` as `failed` event.
	public func attempt(operation: (Value) -> Result<(), Error>) -> SignalProducer<Value, Error> {
		return lift { $0.attempt(operation) }
	}

	/// Apply `operation` to values from `self` with `Success`ful results
	/// mapped on the returned producer and `Failure`s sent as `failed` events.
	///
	/// - parameters:
	///   - operation: A closure that accepts a value and returns a result of
	///                a mapped value as `Success`.
	///
	/// - returns: A producer that sends mapped values from `self` if returned
	///            `Result` is `Success`ful, `failed` events otherwise.
	public func attemptMap<U>(_ operation: (Value) -> Result<U, Error>) -> SignalProducer<U, Error> {
		return lift { $0.attemptMap(operation) }
	}

	/// Throttle values sent by the receiver, so that at least `interval`
	/// seconds pass between each, then forwards them on the given scheduler.
	///
	/// - note: If multiple values are received before the interval has elapsed,
	///         the latest value is the one that will be passed on.
	///
	/// - norw: If `self` terminates while a value is being throttled, that
	///         value will be discarded and the returned producer will terminate
	///         immediately.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait between sent values.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that sends values at least `interval` seconds
	///            appart on a given scheduler.
	public func throttle(_ interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
		return lift { $0.throttle(interval, on: scheduler) }
	}

	/// Debounce values sent by the receiver, such that at least `interval`
	/// seconds pass after the receiver has last sent a value, then
	/// forward the latest value on the given scheduler.
	///
	/// - note: If multiple values are received before the interval has elapsed,
	///         the latest value is the one that will be passed on.
	///
	/// - note: If `self` terminates while a value is being debounced,
	///         that value will be discarded and the returned producer will
	///         terminate immediately.
	///
	/// - parameters:
	///   - interval: A number of seconds to wait before sending a value.
	///   - scheduler: A scheduler to send values on.
	///
	/// - returns: A producer that sends values that are sent from `self` at
	///            least `interval` seconds apart.
	public func debounce(_ interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
		return lift { $0.debounce(interval, on: scheduler) }
	}

	/// Forward events from `self` until `interval`. Then if producer isn't
	/// completed yet, fails with `error` on `scheduler`.
	///
	/// - note: If the interval is 0, the timeout will be scheduled immediately.
	///         The producer must complete synchronously (or on a faster 
	///         scheduler) to avoid the timeout.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait for `self` to complete.
	///   - error: Error to send with `failed` event if `self` is not completed
	///            when `interval` passes.
	///   - scheduler: A scheduler to deliver error on.
	///
	/// - returns: A producer that sends events for at most `interval` seconds,
	///            then, if not `completed` - sends `error` with `failed` event
	///            on `scheduler`.
	public func timeout(after interval: TimeInterval, raising error: Error, on scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
		return lift { $0.timeout(after: interval, raising: error, on: scheduler) }
	}
}

extension SignalProducerProtocol where Value: OptionalProtocol {
	/// Unwraps non-`nil` values and forwards them on the returned signal, `nil`
	/// values are dropped.
	///
	/// - returns: A producer that sends only non-nil values.
	public func ignoreNil() -> SignalProducer<Value.Wrapped, Error> {
		return lift { $0.ignoreNil() }
	}
}

extension SignalProducerProtocol where Value: EventProtocol, Error == NoError {
	/// The inverse of materialize(), this will translate a producer of `Event`
	/// _values_ into a producer of those events themselves.
	///
	/// - returns: A producer that sends values carried by `self` events.
	public func dematerialize() -> SignalProducer<Value.Value, Value.Error> {
		return lift { $0.dematerialize() }
	}
}

extension SignalProducerProtocol where Error == NoError {
	/// Promote a producer that does not generate failures into one that can.
	///
	/// - note: This does not actually cause failers to be generated for the
	///         given producer, but makes it easier to combine with other
	///         producers that may fail; for example, with operators like
	///         `combineLatestWith`, `zipWith`, `flatten`, etc.
	///
	/// - parameters:
	///   - _ An `ErrorType`.
	///
	/// - returns: A producer that has an instantiatable `ErrorType`.
	public func promoteErrors<F: ErrorProtocol>(_: F.Type) -> SignalProducer<Value, F> {
		return lift { $0.promoteErrors(F.self) }
	}
}

extension SignalProducerProtocol where Value: Equatable {
	/// Forward only those values from `self` which are not duplicates of the
	/// immedately preceding value.
	///
	/// - note: The first value is always forwarded.
	///
	/// - returns: A producer that does not send two equal values sequentially.
	public func skipRepeats() -> SignalProducer<Value, Error> {
		return lift { $0.skipRepeats() }
	}
}

extension SignalProducerProtocol {
	/// Forward only those values from `self` that have unique identities across
	/// the set of all values that have been seen.
	///
	/// - note: This causes the identities to be retained to check for 
	///         uniqueness.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value and returns identity
	///                value.
	///
	/// - returns: A producer that sends unique values during its lifetime.
	public func uniqueValues<Identity: Hashable>(_ transform: (Value) -> Identity) -> SignalProducer<Value, Error> {
		return lift { $0.uniqueValues(transform) }
	}
}

extension SignalProducerProtocol where Value: Hashable {
	/// Forward only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// - note: This causes the values to be retained to check for uniqueness.
	///         Providing a function that returns a unique value for each sent
	///         value can help you reduce the memory footprint.
	///
	/// - returns: A producer that sends unique values during its lifetime.
	public func uniqueValues() -> SignalProducer<Value, Error> {
		return lift { $0.uniqueValues() }
	}
}

extension SignalProducerProtocol {
	/// Injects side effects to be performed upon the specified producer events.
	///
	/// - parameters:
	///   - started: A closrure that is invoked when producer is started.
	///   - event: A closure that accepts an event and is invoked on every
	///            received event.
	///   - failed: A closure that accepts error object and is invoked for
	///             `failed` event.
	///   - completed: A closure that is invoked for `completed` event.
	///   - interrupted: A closure that is invoked for `interrupted` event.
	///   - terminated: A closure that is invoked for any terminating event.
	///   - disposed: A closure added as disposable when signal completes.
	///   - next: A closure that accepts a value from `next` event.
	///
	/// - returns: A producer with attached side-effects for given event cases.
	public func on(started: (() -> Void)? = nil, event: ((Event<Value, Error>) -> Void)? = nil, failed: ((Error) -> Void)? = nil, completed: (() -> Void)? = nil, interrupted: (() -> Void)? = nil, terminated: (() -> Void)? = nil, disposed: (() -> Void)? = nil, next: ((Value) -> Void)? = nil) -> SignalProducer<Value, Error> {
		return SignalProducer { observer, compositeDisposable in
			started?()
			self.startWithSignal { signal, disposable in
				compositeDisposable += disposable
				compositeDisposable += signal
					.on(
						event: event,
						failed: failed,
						completed: completed,
						interrupted: interrupted,
						terminated: terminated,
						disposed: disposed,
						next: next
					)
					.observe(observer)
			}
		}
	}

	/// Start the returned producer on the given `Scheduler`.
	///
	/// - note: This implies that any side effects embedded in the producer will
	///         be performed on the given scheduler as well.
	///
	/// - note: Events may still be sent upon other schedulers — this merely
	///         affects where the `start()` method is run.
	///
	/// - parameters:
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that will deliver events on given `scheduler` when
	///            started.
	public func start(on scheduler: SchedulerProtocol) -> SignalProducer<Value, Error> {
		return SignalProducer { observer, compositeDisposable in
			compositeDisposable += scheduler.schedule {
				self.startWithSignal { signal, signalDisposable in
					compositeDisposable += signalDisposable
					signal.observe(observer)
				}
			}
		}
	}
}

extension SignalProducerProtocol {
	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>) -> SignalProducer<(Value, B), Error> {
		return a.combineLatest(with: b)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>) -> SignalProducer<(Value, B, C), Error> {
		return combineLatest(a, b)
			.combineLatest(with: c)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>) -> SignalProducer<(Value, B, C, D), Error> {
		return combineLatest(a, b, c)
			.combineLatest(with: d)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>) -> SignalProducer<(Value, B, C, D, E), Error> {
		return combineLatest(a, b, c, d)
			.combineLatest(with: e)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>) -> SignalProducer<(Value, B, C, D, E, F), Error> {
		return combineLatest(a, b, c, d, e)
			.combineLatest(with: f)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>) -> SignalProducer<(Value, B, C, D, E, F, G), Error> {
		return combineLatest(a, b, c, d, e, f)
			.combineLatest(with: g)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G, H>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>) -> SignalProducer<(Value, B, C, D, E, F, G, H), Error> {
		return combineLatest(a, b, c, d, e, f, g)
			.combineLatest(with: h)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G, H, I>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>) -> SignalProducer<(Value, B, C, D, E, F, G, H, I), Error> {
		return combineLatest(a, b, c, d, e, f, g, h)
			.combineLatest(with: i)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`.
	public static func combineLatest<B, C, D, E, F, G, H, I, J>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>, _ j: SignalProducer<J, Error>) -> SignalProducer<(Value, B, C, D, E, F, G, H, I, J), Error> {
		return combineLatest(a, b, c, d, e, f, g, h, i)
			.combineLatest(with: j)
			.map(repack)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatestWith`. Will return an empty `SignalProducer` if the sequence is empty.
	public static func combineLatest<S: Sequence where S.Iterator.Element == SignalProducer<Value, Error>>(_ producers: S) -> SignalProducer<[Value], Error> {
		var generator = producers.makeIterator()
		if let first = generator.next() {
			let initial = first.map { [$0] }
			return IteratorSequence(generator).reduce(initial) { producer, next in
				producer.combineLatest(with: next).map { $0.0 + [$0.1] }
			}
		}
		
		return .empty
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>) -> SignalProducer<(Value, B), Error> {
		return a.zip(with: b)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>) -> SignalProducer<(Value, B, C), Error> {
		return zip(a, b)
			.zip(with: c)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>) -> SignalProducer<(Value, B, C, D), Error> {
		return zip(a, b, c)
			.zip(with: d)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>) -> SignalProducer<(Value, B, C, D, E), Error> {
		return zip(a, b, c, d)
			.zip(with: e)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>) -> SignalProducer<(Value, B, C, D, E, F), Error> {
		return zip(a, b, c, d, e)
			.zip(with: f)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>) -> SignalProducer<(Value, B, C, D, E, F, G), Error> {
		return zip(a, b, c, d, e, f)
			.zip(with: g)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G, H>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>) -> SignalProducer<(Value, B, C, D, E, F, G, H), Error> {
		return zip(a, b, c, d, e, f, g)
			.zip(with: h)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G, H, I>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>) -> SignalProducer<(Value, B, C, D, E, F, G, H, I), Error> {
		return zip(a, b, c, d, e, f, g, h)
			.zip(with: i)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`.
	public static func zip<B, C, D, E, F, G, H, I, J>(_ a: SignalProducer<Value, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>, _ j: SignalProducer<J, Error>) -> SignalProducer<(Value, B, C, D, E, F, G, H, I, J), Error> {
		return zip(a, b, c, d, e, f, g, h, i)
			.zip(with: j)
			.map(repack)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`. Will return an empty `SignalProducer` if the sequence is empty.
	public static func zip<S: Sequence where S.Iterator.Element == SignalProducer<Value, Error>>(_ producers: S) -> SignalProducer<[Value], Error> {
		var generator = producers.makeIterator()
		if let first = generator.next() {
			let initial = first.map { [$0] }
			return IteratorSequence(generator).reduce(initial) { producer, next in
				producer.zip(with: next).map { $0.0 + [$0.1] }
			}
		}

		return .empty
	}
}

extension SignalProducerProtocol {
	/// Repeat `self` a total of `count` times. In other words, start producer
	/// `count` number of times, each one after previously started producer
	/// completes.
	///
	/// - note: Repeating `1` time results in an equivalent signal producer.
	///
	/// - note: Repeating `0` times results in a producer that instantly
	///         completes.
	///
	/// - parameters:
	///   - count: Number of repetitions.
	///
	/// - returns: A signal producer start sequentially starts `self` after
	///            previously started producer completes.
	public func times(_ count: Int) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return .empty
		} else if count == 1 {
			return producer
		}

		return SignalProducer { observer, disposable in
			let serialDisposable = SerialDisposable()
			disposable += serialDisposable

			func iterate(_ current: Int) {
				self.startWithSignal { signal, signalDisposable in
					serialDisposable.innerDisposable = signalDisposable

					signal.observe { event in
						if case .completed = event {
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

	/// Ignore failures up to `count` times.
	///
	/// - precondition: `count` must be non-negative integer.
	///
	/// - parameters:
	///   - count: Number of retries.
	///
	/// - returns: A signal producer that restarts up to `count` times.
	public func retry(upTo count: Int) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return producer
		} else {
			return flatMapError { _ in
				self.retry(upTo: count - 1)
			}
		}
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded. 
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<U>(_ replacement: SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return SignalProducer<U, Error> { observer, observerDisposable in
			self.startWithSignal { signal, signalDisposable in
				observerDisposable += signalDisposable

				signal.observe { event in
					switch event {
					case let .failed(error):
						observer.sendFailed(error)
					case .completed:
						observerDisposable += replacement.start(observer)
					case .interrupted:
						observer.sendInterrupted()
					case .next:
						break
					}
				}
			}
		}
	}

	/// Start the producer, then block, waiting for the first value.
	///
	/// When a single value or error is sent, the returned `Result` will
	/// represent those cases. However, when no values are sent, `nil` will be
	/// returned.
	///
	/// - returns: Result when single `next` or `failed` event is received.
	///            `nil` when no events are received.
	public func first() -> Result<Value, Error>? {
		return take(first: 1).single()
	}

	/// Start the producer, then block, waiting for events: Next and
	/// Completed.
	///
	/// When a single value or error is sent, the returned `Result` will
	/// represent those cases. However, when no values are sent, or when more
	/// than one value is sent, `nil` will be returned.
	///
	/// - returns: Result when single `next` or `failed` event is received. 
	///            `nil` when 0 or more than 1 events are received.
	public func single() -> Result<Value, Error>? {
		let semaphore = DispatchSemaphore(value: 0)
		var result: Result<Value, Error>?

		take(first: 2).start { event in
			switch event {
			case let .next(value):
				if result != nil {
					// Move into failure state after recieving another value.
					result = nil
					return
				}
				result = .success(value)
			case let .failed(error):
				result = .failure(error)
				semaphore.signal()
			case .completed, .interrupted:
				semaphore.signal()
			}
		}

		semaphore.wait()
		return result
	}

	/// Start the producer, then block, waiting for the last value.
	///
	/// When a single value or error is sent, the returned `Result` will
	/// represent those cases. However, when no values are sent, `nil` will be
	/// returned.
	///
	/// - returns: Result when single `next` or `failed` event is received.
	///            `nil` when no events are received.
	public func last() -> Result<Value, Error>? {
		return take(last: 1).single()
	}

	/// Starts the producer, then blocks, waiting for completion.
	///
	/// When a completion or error is sent, the returned `Result` will represent
	/// those cases.
	///
	/// - returns: Result when single `Completion` or `failed` event is 
	///            received.
	public func wait() -> Result<(), Error> {
		return then(SignalProducer<(), Error>(value: ())).last() ?? .success(())
	}

	/// Creates a new `SignalProducer` that will multicast values emitted by
	/// the underlying producer, up to `capacity`.
	/// This means that all clients of this `SignalProducer` will see the same
	/// version of the emitted values/errors.
	///
	/// The underlying `SignalProducer` will not be started until `self` is
	/// started for the first time. When subscribing to this producer, all
	/// previous values (up to `capacity`) will be emitted, followed by any new
	/// values.
	///
	/// If you find yourself needing *the current value* (the last buffered
	/// value) you should consider using `PropertyType` instead, which, unlike
	/// this operator, will guarantee at compile time that there's always a
	/// buffered value. This operator is not recommended in most cases, as it
	/// will introduce an implicit relationship between the original client and
	/// the rest, so consider alternatives like `PropertyType`, or representing
	/// your stream using a `Signal` instead.
	///
	/// This operator is only recommended when you absolutely need to introduce
	/// a layer of caching in front of another `SignalProducer`.
	///
	/// - note: This operator has the same semantics as `SignalProducer.buffer`.
	///
	/// - precondtion: `capacity` must be non-negative integer.
	///
	/// - parameters:
	///   - capcity: Number of values to hold.
	///
	/// - returns: A caching producer that will hold up to last `capacity`
	///            values.
	public func replayLazily(upTo capacity: Int) -> SignalProducer<Value, Error> {
		precondition(capacity >= 0, "Invalid capacity: \(capacity)")

		var producer: SignalProducer<Value, Error>?
		var producerObserver: SignalProducer<Value, Error>.ProducedSignal.Observer?

		let lock = Lock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.SignalProducer.replayLazily"

		// This will go "out of scope" when the returned `SignalProducer` goes
		// out of scope. This lets us know when we're supposed to dispose the
		// underlying producer. This is necessary because `struct`s don't have
		// `deinit`.
		let token = DeallocationToken()

		return SignalProducer { observer, disposable in
			var token: DeallocationToken? = token
			let initializedProducer: SignalProducer<Value, Error>
			let initializedObserver: SignalProducer<Value, Error>.ProducedSignal.Observer
			let shouldStartUnderlyingProducer: Bool

			lock.lock()
			if let producer = producer, producerObserver = producerObserver {
				(initializedProducer, initializedObserver) = (producer, producerObserver)
				shouldStartUnderlyingProducer = false
			} else {
				let (producerTemp, observerTemp) = SignalProducer<Value, Error>.bufferingProducer(upTo: capacity)

				(producer, producerObserver) = (producerTemp, observerTemp)
				(initializedProducer, initializedObserver) = (producerTemp, observerTemp)
				shouldStartUnderlyingProducer = true
			}
			lock.unlock()

			// subscribe `observer` before starting the underlying producer.
			disposable += initializedProducer.start(observer)
			disposable += {
				// Don't dispose of the original producer until all observers
				// have terminated.
				token = nil
			}

			if shouldStartUnderlyingProducer {
				self.take(until: token!.deallocSignal)
					.start(initializedObserver)
			}
		}
	}
}

extension SignalProducer {
	private static func bufferingProducer(upTo capacity: Int) -> (SignalProducer, Signal<Value, Error>.Observer) {
		precondition(capacity >= 0, "Invalid capacity: \(capacity)")

		// Used as an atomic variable so we can remove observers without needing
		// to run on a serial queue.
		let state: Atomic<BufferState<Value, Error>> = Atomic(BufferState())

		let producer = self.init { observer, disposable in
			// Assigned to when replay() is invoked synchronously below.
			var token: RemovalToken?

			let replayBuffer = ReplayBuffer<Value>()
			var replayValues: [Value] = []
			var replayToken: RemovalToken?
			var next = state.modify { state in
				replayValues = state.values
				if replayValues.isEmpty {
					token = state.observers?.insert(observer)
				} else {
					replayToken = state.replayBuffers.insert(replayBuffer)
				}
			}

			while !replayValues.isEmpty {
				replayValues.forEach(observer.sendNext)

				next = state.modify { state in
					replayValues = replayBuffer.values
					replayBuffer.values = []
					if replayValues.isEmpty {
						if let replayToken = replayToken {
							state.replayBuffers.remove(using: replayToken)
						}
						token = state.observers?.insert(observer)
					}
				}
			}

			if let terminationEvent = next.terminationEvent {
				observer.action(terminationEvent)
			}

			if let token = token {
				disposable += {
					state.modify { state in
						state.observers?.remove(using: token)
					}
				}
			}
		}

		let bufferingObserver: Signal<Value, Error>.Observer = Observer { event in
			let originalState = state.modify { state in
				if let value = event.value {
					state.add(value, upTo: capacity)
				} else {
					// Disconnect all observers and prevent future
					// attachments.
					state.terminationEvent = event
					state.observers = nil
				}
			}

			originalState.observers?.forEach { $0.action(event) }
		}

		return (producer, bufferingObserver)
	}
}

/// A uniquely identifying token for Observers that are replaying values in
/// BufferState.
private final class ReplayBuffer<Value> {
	private var values: [Value] = []
}

private struct BufferState<Value, Error: ErrorProtocol> {
	/// All values in the buffer.
	var values: [Value] = []

	/// Any terminating event sent to the buffer.
	///
	/// This will be nil if termination has not occurred.
	var terminationEvent: Event<Value, Error>?

	/// The observers currently attached to the buffered producer, or nil if the
	/// producer was terminated.
	var observers: Bag<Signal<Value, Error>.Observer>? = Bag()

	/// The set of unused replay token identifiers.
	var replayBuffers: Bag<ReplayBuffer<Value>> = Bag()

	/// Appends a new value to the buffer, trimming it down to the given capacity
	/// if necessary.
	mutating func add(_ value: Value, upTo capacity: Int) {
		precondition(capacity >= 0)

		for buffer in replayBuffers {
			buffer.values.append(value)
		}

		if capacity == 0 {
			values = []
			return
		}

		if capacity == 1 {
			values = [ value ]
			return
		}

		values.append(value)

		let overflow = values.count - capacity
		if overflow > 0 {
			values.removeSubrange(0..<overflow)
		}
	}
}

/// Create a repeating timer of the given interval, with a reasonable default
/// leeway, sending updates on the given scheduler.
///
/// - note: This timer will never complete naturally, so all invocations of
///         `start()` must be disposed to avoid leaks.
///
/// - precondition: Interval must be non-negative number.
///
/// - parameters:
///   - interval: An interval between invocations.
///   - scheduler: A scheduler to deliver events on.
///
/// - returns: A producer that sends `NSDate` values every `interval` seconds.
public func timer(interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> SignalProducer<Date, NoError> {
	// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
	// at least 10% of the timer interval.
	return timer(interval: interval, on: scheduler, leeway: interval * 0.1)
}

/// Creates a repeating timer of the given interval, sending updates on the
/// given scheduler.
///
/// - note: This timer will never complete naturally, so all invocations of
///         `start()` must be disposed to avoid leaks.
///
/// - precondition: Interval must be non-negative number.
///
/// - precondition: Leeway must be non-negative number.
///
/// - parameters:
///   - interval: An interval between invocations.
///   - scheduler: A scheduler to deliver events on.
///   - leeway: Interval leeway. Apple's "Power Efficiency Guide for Mac Apps"
///             recommends a leeway of at least 10% of the timer interval.
///
/// - returns: A producer that sends `NSDate` values every `interval` seconds.
public func timer(interval: TimeInterval, on scheduler: DateSchedulerProtocol, leeway: TimeInterval) -> SignalProducer<Date, NoError> {
	precondition(interval >= 0)
	precondition(leeway >= 0)

	return SignalProducer { observer, compositeDisposable in
		compositeDisposable += scheduler.schedule(after: scheduler.currentDate.addingTimeInterval(interval),
		                                          interval: interval,
		                                          leeway: leeway,
		                                          action: { observer.sendNext(scheduler.currentDate) })
	}
}
