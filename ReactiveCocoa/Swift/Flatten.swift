//
//  Flatten.swift
//  ReactiveCocoa
//
//  Created by Neil Pankey on 11/30/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

import enum Result.NoError

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


extension SignalType where Value: SignalProducerType, Error == Value.Error {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` or an active inner producer fails, the returned signal will
	/// forward that failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		switch strategy {
		case .Merge:
			return self.merge()

		case .Concat:
			return self.concat()

		case .Latest:
			return self.switchToLatest()
		}
	}
}

extension SignalType where Value: SignalProducerType, Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If an active inner producer fails, the returned signal will forward that
	/// failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalType where Value: SignalProducerType, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		switch strategy {
		case .Merge:
			return self.merge()

		case .Concat:
			return self.concat()

		case .Latest:
			return self.switchToLatest()
		}
	}
}

extension SignalType where Value: SignalProducerType, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` fails, the returned signal will forward that failure
	/// immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProducerType where Value: SignalProducerType, Error == Value.Error {
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` or an active inner producer fails, the returned producer will
	/// forward that failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		switch strategy {
		case .Merge:
			return self.merge()

		case .Concat:
			return self.concat()

		case .Latest:
			return self.switchToLatest()
		}
	}
}

extension SignalProducerType where Value: SignalProducerType, Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If an active inner producer fails, the returned producer will forward that
	/// failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducerType where Value: SignalProducerType, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		switch strategy {
		case .Merge:
			return self.merge()

		case .Concat:
			return self.concat()

		case .Latest:
			return self.switchToLatest()
		}
	}
}

extension SignalProducerType where Value: SignalProducerType, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` fails, the returned signal will forward that failure
	/// immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalType where Value: SignalType, Error == Value.Error {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` or an active inner signal emits an error, the returned
	/// signal will forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalType where Value: SignalType, Error == NoError {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If an active inner signal emits an error, the returned signal will
	/// forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalType where Value: SignalType, Error == NoError, Value.Error == NoError {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalType where Value: SignalType, Value.Error == NoError {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` emits an error, the returned signal will forward
	/// that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalType where Value: SequenceType, Error == NoError {
	/// Flattens the `sequence` value sent by `signal` according to
	/// the semantics of the given strategy.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> Signal<Value.Generator.Element, Error> {
		return self.flatMap(strategy) { .init(values: $0) }
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
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProducerType where Value: SignalType, Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If an active inner signal emits an error, the returned producer will
	/// forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducerType where Value: SignalType, Error == NoError, Value.Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProducerType where Value: SignalType, Value.Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` emits an error, the returned producer will forward that
	/// error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProducerType where Value: SequenceType, Error == NoError {
	/// Flattens the `sequence` value sent by `producer` according to
	/// the semantics of the given strategy.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatten(strategy: FlattenStrategy) -> SignalProducer<Value.Generator.Element, Error> {
		return self.flatMap(strategy) { .init(values: $0) }
	}
}

extension SignalType where Value: SignalProducerType, Error == Value.Error {
	/// Returns a signal which sends all the values from producer signal emitted from
	/// `signal`, waiting until each inner producer completes before beginning to
	/// send the values from the next inner producer.
	///
	/// If any of the inner producers fail, the returned signal will forward
	/// that failure immediately
	///
	/// The returned signal completes only when `signal` and all producers
	/// emitted from `signal` complete.
	private func concat() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { relayObserver in
			let disposable = CompositeDisposable()
			let relayDisposable = CompositeDisposable()

			disposable += relayDisposable
			disposable += self.observeConcat(relayObserver, relayDisposable)

			return disposable
		}
	}

	private func observeConcat(observer: Observer<Value.Value, Error>, _ disposable: CompositeDisposable? = nil) -> Disposable? {
		let state = ConcatState(observer: observer, disposable: disposable)

		return self.observe { event in
			switch event {
			case let .Next(value):
				state.enqueueSignalProducer(value.producer)

			case let .Failed(error):
				observer.sendFailed(error)

			case .Completed:
				// Add one last producer to the queue, whose sole job is to
				// "turn out the lights" by completing `observer`.
				state.enqueueSignalProducer(SignalProducer.empty.on(completed: {
					observer.sendCompleted()
				}))

			case .Interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerType where Value: SignalProducerType, Error == Value.Error {
	/// Returns a producer which sends all the values from each producer emitted from
	/// `producer`, waiting until each inner producer completes before beginning to
	/// send the values from the next inner producer.
	///
	/// If any of the inner producers emit an error, the returned producer will emit
	/// that error.
	///
	/// The returned producer completes only when `producer` and all producers
	/// emitted from `producer` complete.
	private func concat() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, disposable in
			self.startWithSignal { signal, signalDisposable in
				disposable += signalDisposable
				signal.observeConcat(observer, disposable)
			}
		}
	}
}

extension SignalProducerType {
	/// `concat`s `next` onto `self`.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func concat(next: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return SignalProducer<SignalProducer<Value, Error>, Error>(values: [ self.producer, next ]).flatten(.Concat)
	}
	
	/// `concat`s `value` onto `self`.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func concat(value value: Value) -> SignalProducer<Value, Error> {
		return self.concat(SignalProducer(value: value))
	}
	
	/// `concat`s `self` onto initial `previous`.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func prefix<P: SignalProducerType where P.Value == Value, P.Error == Error>(previous: P) -> SignalProducer<Value, Error> {
		return previous.concat(self.producer)
	}
	
	/// `concat`s `self` onto initial `value`.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func prefix(value value: Value) -> SignalProducer<Value, Error> {
		return self.prefix(SignalProducer(value: value))
	}
}

private final class ConcatState<Value, Error: ErrorType> {
	/// The observer of a started `concat` producer.
	let observer: Observer<Value, Error>

	/// The top level disposable of a started `concat` producer.
	let disposable: CompositeDisposable?

	/// The active producer, if any, and the producers waiting to be started.
	let queuedSignalProducers: Atomic<[SignalProducer<Value, Error>]> = Atomic([])

	init(observer: Signal<Value, Error>.Observer, disposable: CompositeDisposable?) {
		self.observer = observer
		self.disposable = disposable
	}

	func enqueueSignalProducer(producer: SignalProducer<Value, Error>) {
		if let d = disposable where d.disposed {
			return
		}

		var shouldStart = true

		queuedSignalProducers.modify {
			// An empty queue means the concat is idle, ready & waiting to start
			// the next producer.
			var queue = $0
			shouldStart = queue.isEmpty
			queue.append(producer)
			return queue
		}

		if shouldStart {
			startNextSignalProducer(producer)
		}
	}

	func dequeueSignalProducer() -> SignalProducer<Value, Error>? {
		if let d = disposable where d.disposed {
			return nil
		}

		var nextSignalProducer: SignalProducer<Value, Error>?

		queuedSignalProducers.modify {
			// Active producers remain in the queue until completed. Since
			// dequeueing happens at completion of the active producer, the
			// first producer in the queue can be removed.
			var queue = $0
			if !queue.isEmpty { queue.removeAtIndex(0) }
			nextSignalProducer = queue.first
			return queue
		}

		return nextSignalProducer
	}

	/// Subscribes to the given signal producer.
	func startNextSignalProducer(signalProducer: SignalProducer<Value, Error>) {
		signalProducer.startWithSignal { signal, disposable in
			let handle = self.disposable?.addDisposable(disposable) ?? nil

			signal.observe { event in
				switch event {
				case .Completed, .Interrupted:
					handle?.remove()

					if let nextSignalProducer = self.dequeueSignalProducer() {
						self.startNextSignalProducer(nextSignalProducer)
					}

				case .Next, .Failed:
					self.observer.action(event)
				}
			}
		}
	}
}

extension SignalType where Value: SignalProducerType, Error == Value.Error {
	/// Merges a `signal` of SignalProducers down into a single signal, biased toward the producer
	/// added earlier. Returns a Signal that will forward events from the inner producers as they arrive.
	private func merge() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { relayObserver in
			let disposable = CompositeDisposable()
			let relayDisposable = CompositeDisposable()

			disposable += relayDisposable
			disposable += self.observeMerge(relayObserver, relayDisposable)

			return disposable
		}
	}

	private func observeMerge(observer: Observer<Value.Value, Error>, _ disposable: CompositeDisposable) -> Disposable? {
		let inFlight = Atomic(1)
		let decrementInFlight = {
			let orig = inFlight.modify { $0 - 1 }
			if orig == 1 {
				observer.sendCompleted()
			}
		}

		return self.observe { event in
			switch event {
			case let .Next(producer):
				producer.startWithSignal { innerSignal, innerDisposable in
					inFlight.modify { $0 + 1 }
					let handle = disposable.addDisposable(innerDisposable)

					innerSignal.observe { event in
						switch event {
						case .Completed, .Interrupted:
							handle.remove()
							decrementInFlight()

						case .Next, .Failed:
							observer.action(event)
						}
					}
				}

			case let .Failed(error):
				observer.sendFailed(error)

			case .Completed:
				decrementInFlight()

			case .Interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerType where Value: SignalProducerType, Error == Value.Error {
	/// Merges a `signal` of SignalProducers down into a single signal, biased toward the producer
	/// added earlier. Returns a Signal that will forward events from the inner producers as they arrive.
	private func merge() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { relayObserver, disposable in
			self.startWithSignal { signal, signalDisposable in
				disposable.addDisposable(signalDisposable)

				signal.observeMerge(relayObserver, disposable)
			}

		}
	}
}

extension SignalType {
	/// Merges the given signals into a single `Signal` that will emit all values
	/// from each of them, and complete when all of them have completed.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public static func merge<Seq: SequenceType, S: SignalType where S.Value == Value, S.Error == Error, Seq.Generator.Element == S>(signals: Seq) -> Signal<Value, Error> {
		let producer = SignalProducer<S, Error>(values: signals)
		var result: Signal<Value, Error>!

		producer.startWithSignal { signal, _ in
			result = signal.flatten(.Merge)
		}

		return result
	}
	
	/// Merges the given signals into a single `Signal` that will emit all values
	/// from each of them, and complete when all of them have completed.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public static func merge<S: SignalType where S.Value == Value, S.Error == Error>(signals: S...) -> Signal<Value, Error> {
		return Signal.merge(signals)
	}
}

extension SignalProducerType {
	/// Merges the given producers into a single `SignalProducer` that will emit all values
	/// from each of them, and complete when all of them have completed.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public static func merge<Seq: SequenceType, S: SignalProducerType where S.Value == Value, S.Error == Error, Seq.Generator.Element == S>(producers: Seq) -> SignalProducer<Value, Error> {
		return SignalProducer(values: producers).flatten(.Merge)
	}
	
	/// Merges the given producers into a single `SignalProducer` that will emit all values
	/// from each of them, and complete when all of them have completed.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public static func merge<S: SignalProducerType where S.Value == Value, S.Error == Error>(producers: S...) -> SignalProducer<Value, Error> {
		return SignalProducer.merge(producers)
	}
}

extension SignalType where Value: SignalProducerType, Error == Value.Error {
	/// Returns a signal that forwards values from the latest signal sent on
	/// `signal`, ignoring values sent on previous inner signal.
	///
	/// An error sent on `signal` or the latest inner signal will be sent on the
	/// returned signal.
	///
	/// The returned signal completes when `signal` and the latest inner
	/// signal have both completed.
	private func switchToLatest() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { observer in
			let composite = CompositeDisposable()
			let serial = SerialDisposable()

			composite += serial
			composite += self.observeSwitchToLatest(observer, serial)

			return composite
		}
	}

	private func observeSwitchToLatest(observer: Observer<Value.Value, Error>, _ latestInnerDisposable: SerialDisposable) -> Disposable? {
		let state = Atomic(LatestState<Value, Error>())

		return self.observe { event in
			switch event {
			case let .Next(innerProducer):
				innerProducer.startWithSignal { innerSignal, innerDisposable in
					state.modify {
						// When we replace the disposable below, this prevents the
						// generated Interrupted event from doing any work.
						var state = $0
						state.replacingInnerSignal = true
						return state
					}

					latestInnerDisposable.innerDisposable = innerDisposable

					state.modify {
						var state = $0
						state.replacingInnerSignal = false
						state.innerSignalComplete = false
						return state
					}

					innerSignal.observe { event in
						switch event {
						case .Interrupted:
							// If interruption occurred as a result of a new producer
							// arriving, we don't want to notify our observer.
							let original = state.modify {
								var state = $0
								if !state.replacingInnerSignal {
									state.innerSignalComplete = true
								}

								return state
							}

							if !original.replacingInnerSignal && original.outerSignalComplete {
								observer.sendCompleted()
							}

						case .Completed:
							let original = state.modify {
								var state = $0
								state.innerSignalComplete = true
								return state
							}

							if original.outerSignalComplete {
								observer.sendCompleted()
							}

						case .Next, .Failed:
							observer.action(event)
						}
					}
				}
			case let .Failed(error):
				observer.sendFailed(error)
			case .Completed:
				let original = state.modify {
					var state = $0
					state.outerSignalComplete = true
					return state
				}

				if original.innerSignalComplete {
					observer.sendCompleted()
				}
			case .Interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerType where Value: SignalProducerType, Error == Value.Error {
	/// Returns a signal that forwards values from the latest signal sent on
	/// `signal`, ignoring values sent on previous inner signal.
	///
	/// An error sent on `signal` or the latest inner signal will be sent on the
	/// returned signal.
	///
	/// The returned signal completes when `signal` and the latest inner
	/// signal have both completed.
	private func switchToLatest() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, disposable in
			let latestInnerDisposable = SerialDisposable()
			disposable.addDisposable(latestInnerDisposable)

			self.startWithSignal { signal, signalDisposable in
				disposable += signalDisposable
				disposable += signal.observeSwitchToLatest(observer, latestInnerDisposable)
			}
		}
	}
}

private struct LatestState<Value, Error: ErrorType> {
	var outerSignalComplete: Bool = false
	var innerSignalComplete: Bool = true
	
	var replacingInnerSignal: Bool = false
}


extension SignalType {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` or any of the created producers fail, the returned signal
	/// will forward that failure immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, Error>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` fails, the returned signal will forward that failure
	/// immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, NoError>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` or any of the created signals emit an error, the returned
	/// signal will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, Error>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` emits an error, the returned signal will forward that
	/// error immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, NoError>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}
}

extension SignalType where Error == NoError {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created signals emit an error, the returned signal
	/// will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U, E>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, E>) -> Signal<U, E> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, NoError>) -> Signal<U, NoError> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created signals emit an error, the returned signal
	/// will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U, E>(strategy: FlattenStrategy, transform: Value -> Signal<U, E>) -> Signal<U, E> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, NoError>) -> Signal<U, NoError> {
		return map(transform).flatten(strategy)
	}
}

extension SignalProducerType {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` or any of the created producers fail, the returned producer
	/// will forward that failure immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` fails, the returned producer will forward that failure
	/// immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, NoError>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` or any of the created signals emit an error, the returned
	/// producer will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` emits an error, the returned producer will forward that
	/// error immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, NoError>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}
}

extension SignalProducerType where Error == NoError {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created producers fail, the returned producer will
	/// forward that failure immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U, E>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, E>) -> SignalProducer<U, E> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> SignalProducer<U, NoError>) -> SignalProducer<U, NoError> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created signals emit an error, the returned
	/// producer will forward that error immediately.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U, E>(strategy: FlattenStrategy, transform: Value -> Signal<U, E>) -> SignalProducer<U, E> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMap<U>(strategy: FlattenStrategy, transform: Value -> Signal<U, NoError>) -> SignalProducer<U, NoError> {
		return map(transform).flatten(strategy)
	}
}


extension SignalType {
	/// Catches any failure that may occur on the input signal, mapping to a new producer
	/// that starts in its place.
	@warn_unused_result(message="Did you forget to call `observe` on the signal?")
	public func flatMapError<F>(handler: Error -> SignalProducer<Value, F>) -> Signal<Value, F> {
		return Signal { observer in
			self.observeFlatMapError(handler, observer, SerialDisposable())
		}
	}

	private func observeFlatMapError<F>(handler: Error -> SignalProducer<Value, F>, _ observer: Observer<Value, F>, _ serialDisposable: SerialDisposable) -> Disposable? {
		return self.observe { event in
			switch event {
			case let .Next(value):
				observer.sendNext(value)
			case let .Failed(error):
				handler(error).startWithSignal { signal, disposable in
					serialDisposable.innerDisposable = disposable
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

extension SignalProducerType {
	/// Catches any failure that may occur on the input producer, mapping to a new producer
	/// that starts in its place.
	@warn_unused_result(message="Did you forget to call `start` on the producer?")
	public func flatMapError<F>(handler: Error -> SignalProducer<Value, F>) -> SignalProducer<Value, F> {
		return SignalProducer { observer, disposable in
			let serialDisposable = SerialDisposable()
			disposable.addDisposable(serialDisposable)

			self.startWithSignal { signal, signalDisposable in
				serialDisposable.innerDisposable = signalDisposable

				signal.observeFlatMapError(handler, observer, serialDisposable)
			}
		}
	}
}
