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
	/// The resulting producer will complete only when all inputs have
	/// completed.
	case merge

	/// The producers should be concatenated, so that their values are sent in
	/// the order of the producers themselves.
	///
	/// The resulting producer will complete only when all inputs have
	/// completed.
	case concat

	/// Only the events from the latest input producer should be considered for
	/// the output. Any producers received before that point will be disposed
	/// of.
	///
	/// The resulting producer will complete only when the producer-of-producers
	/// and the latest producer has completed.
	case latest
}


extension SignalProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` or an active inner producer fails, the returned
	///         signal will forward that failure immediately.
	///
	/// - note: `interrupted` events on inner producers will be treated like
	///         `Completed events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		switch strategy {
		case .merge:
			return self.merge()

		case .concat:
			return self.concat()

		case .latest:
			return self.switchToLatest()
		}
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If an active inner producer fails, the returned signal will
	///         forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		switch strategy {
		case .merge:
			return self.merge()

		case .concat:
			return self.concat()

		case .latest:
			return self.switchToLatest()
		}
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` fails, the returned signal will forward that failure
	///         immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - note: If `producer` or an active inner producer fails, the returned
	///         producer will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		switch strategy {
		case .merge:
			return self.merge()

		case .concat:
			return self.concat()

		case .latest:
			return self.switchToLatest()
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - note: If an active inner producer fails, the returned producer will
	///         forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		switch strategy {
		case .merge:
			return self.merge()

		case .concat:
			return self.concat()

		case .latest:
			return self.switchToLatest()
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Value.Error == NoError {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` fails, the returned signal will forward that failure
	///         immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProtocol where Value: SignalProtocol, Error == Value.Error {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` or an active inner signal emits an error, the
	///         returned signal will forward that error immediately.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProtocol where Value: SignalProtocol, Error == NoError {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If an active inner signal emits an error, the returned signal
	///         will forward that error immediately.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProtocol where Value: SignalProtocol, Error == NoError, Value.Error == NoError {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProtocol where Value: SignalProtocol, Value.Error == NoError {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` emits an error, the returned signal will forward
	///         that error immediately.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProtocol where Value: Sequence, Error == NoError {
	/// Flattens the `sequence` value sent by `signal` according to
	/// the semantics of the given strategy.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Iterator.Element, Error> {
		return self.flatMap(strategy) { .init(values: $0) }
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Error == Value.Error {
	/// Flattens the inner signals sent upon `producer` (into a single producer
	/// of values), according to the semantics of the given strategy.
	///
	/// - note: If `producer` or an active inner signal emits an error, the
	///         returned producer will forward that error immediately.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer
	/// of values), according to the semantics of the given strategy.
	///
	/// - note: If an active inner signal emits an error, the returned producer
	///         will forward that error immediately.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Error == NoError, Value.Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer
	/// of values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Value.Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer
	/// of values), according to the semantics of the given strategy.
	///
	/// - note: If `producer` emits an error, the returned producer will forward
	///         that error immediately.
	///
	/// - warning: `interrupted` events on inner signals will be treated like
	///            `completed` events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProducerProtocol where Value: Sequence, Error == NoError {
	/// Flattens the `sequence` value sent by `producer` according to
	/// the semantics of the given strategy.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Iterator.Element, Error> {
		return self.flatMap(strategy) { .init(values: $0) }
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Returns a signal which sends all the values from producer signal emitted
	/// from `signal`, waiting until each inner producer completes before
	/// beginning to send the values from the next inner producer.
	///
	/// - note: If any of the inner producers fail, the returned signal will
	///         forward that failure immediately
	///
	/// - note: The returned signal completes only when `signal` and all
	///         producers emitted from `signal` complete.
	private func concat() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { relayObserver in
			let disposable = CompositeDisposable()
			let relayDisposable = CompositeDisposable()

			disposable += relayDisposable
			disposable += self.observeConcat(relayObserver, relayDisposable)

			return disposable
		}
	}

	private func observeConcat(_ observer: Observer<Value.Value, Error>, _ disposable: CompositeDisposable? = nil) -> Disposable? {
		let state = ConcatState(observer: observer, disposable: disposable)

		return self.observe { event in
			switch event {
			case let .next(value):
				state.enqueueSignalProducer(value.producer)

			case let .failed(error):
				observer.sendFailed(error)

			case .completed:
				// Add one last producer to the queue, whose sole job is to
				// "turn out the lights" by completing `observer`.
				state.enqueueSignalProducer(SignalProducer.empty.on(completed: {
					observer.sendCompleted()
				}))

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Returns a producer which sends all the values from each producer emitted
	/// from `producer`, waiting until each inner producer completes before
	/// beginning to send the values from the next inner producer.
	///
	/// - note: If any of the inner producers emit an error, the returned
	///         producer will emit that error.
	///
	/// - note: The returned producer completes only when `producer` and all
	///         producers emitted from `producer` complete.
	private func concat() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, disposable in
			self.startWithSignal { signal, signalDisposable in
				disposable += signalDisposable
				_ = signal.observeConcat(observer, disposable)
			}
		}
	}
}

extension SignalProducerProtocol {
	/// `concat`s `next` onto `self`.
	public func concat(_ next: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return SignalProducer<SignalProducer<Value, Error>, Error>(values: [ self.producer, next ]).flatten(.concat)
	}
	
	/// `concat`s `value` onto `self`.
	public func concat(value: Value) -> SignalProducer<Value, Error> {
		return self.concat(SignalProducer(value: value))
	}
	
	/// `concat`s `self` onto initial `previous`.
	public func prefix<P: SignalProducerProtocol where P.Value == Value, P.Error == Error>(_ previous: P) -> SignalProducer<Value, Error> {
		return previous.concat(self.producer)
	}
	
	/// `concat`s `self` onto initial `value`.
	public func prefix(value: Value) -> SignalProducer<Value, Error> {
		return self.prefix(SignalProducer(value: value))
	}
}

private final class ConcatState<Value, Error: ErrorProtocol> {
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

	func enqueueSignalProducer(_ producer: SignalProducer<Value, Error>) {
		if let d = disposable, d.isDisposed {
			return
		}

		var shouldStart = true

		queuedSignalProducers.modify { queue in
			// An empty queue means the concat is idle, ready & waiting to start
			// the next producer.
			shouldStart = queue.isEmpty
			queue.append(producer)
		}

		if shouldStart {
			startNextSignalProducer(producer)
		}
	}

	func dequeueSignalProducer() -> SignalProducer<Value, Error>? {
		if let d = disposable, d.isDisposed {
			return nil
		}

		var nextSignalProducer: SignalProducer<Value, Error>?

		queuedSignalProducers.modify { queue in
			// Active producers remain in the queue until completed. Since
			// dequeueing happens at completion of the active producer, the
			// first producer in the queue can be removed.
			if !queue.isEmpty { queue.remove(at: 0) }
			nextSignalProducer = queue.first
		}

		return nextSignalProducer
	}

	/// Subscribes to the given signal producer.
	func startNextSignalProducer(_ signalProducer: SignalProducer<Value, Error>) {
		signalProducer.startWithSignal { signal, disposable in
			let handle = self.disposable?.add(disposable) ?? nil

			signal.observe { event in
				switch event {
				case .completed, .interrupted:
					handle?.remove()

					if let nextSignalProducer = self.dequeueSignalProducer() {
						self.startNextSignalProducer(nextSignalProducer)
					}

				case .next, .failed:
					self.observer.action(event)
				}
			}
		}
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Merges a `signal` of SignalProducers down into a single signal, biased
	/// toward the producer added earlier. Returns a Signal that will forward
	/// events from the inner producers as they arrive.
	private func merge() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { relayObserver in
			let disposable = CompositeDisposable()
			let relayDisposable = CompositeDisposable()

			disposable += relayDisposable
			disposable += self.observeMerge(relayObserver, relayDisposable)

			return disposable
		}
	}

	private func observeMerge(_ observer: Observer<Value.Value, Error>, _ disposable: CompositeDisposable) -> Disposable? {
		let inFlight = Atomic(1)
		let decrementInFlight = {
			let orig = inFlight.modify { $0 -= 1 }
			if orig == 1 {
				observer.sendCompleted()
			}
		}

		return self.observe { event in
			switch event {
			case let .next(producer):
				producer.startWithSignal { innerSignal, innerDisposable in
					inFlight.modify { $0 += 1 }
					let handle = disposable.add(innerDisposable)

					innerSignal.observe { event in
						switch event {
						case .completed, .interrupted:
							handle.remove()
							decrementInFlight()

						case .next, .failed:
							observer.action(event)
						}
					}
				}

			case let .failed(error):
				observer.sendFailed(error)

			case .completed:
				decrementInFlight()

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Merges a `signal` of SignalProducers down into a single signal, biased
	/// toward the producer added earlier. Returns a Signal that will forward
	/// events from the inner producers as they arrive.
	private func merge() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { relayObserver, disposable in
			self.startWithSignal { signal, signalDisposable in
				disposable += signalDisposable

				_ = signal.observeMerge(relayObserver, disposable)
			}

		}
	}
}

extension SignalProtocol {
	/// Merges the given signals into a single `Signal` that will emit all
	/// values from each of them, and complete when all of them have completed.
	public static func merge<Seq: Sequence, S: SignalProtocol where S.Value == Value, S.Error == Error, Seq.Iterator.Element == S>(_ signals: Seq) -> Signal<Value, Error> {
		let producer = SignalProducer<S, Error>(values: signals)
		var result: Signal<Value, Error>!

		producer.startWithSignal { signal, _ in
			result = signal.flatten(.merge)
		}

		return result
	}
	
	/// Merges the given signals into a single `Signal` that will emit all
	/// values from each of them, and complete when all of them have completed.
	public static func merge<S: SignalProtocol where S.Value == Value, S.Error == Error>(_ signals: S...) -> Signal<Value, Error> {
		return Signal.merge(signals)
	}
}

extension SignalProducerProtocol {
	/// Merges the given producers into a single `SignalProducer` that will emit
	/// all values from each of them, and complete when all of them have
	/// completed.
	public static func merge<Seq: Sequence, S: SignalProducerProtocol where S.Value == Value, S.Error == Error, Seq.Iterator.Element == S>(_ producers: Seq) -> SignalProducer<Value, Error> {
		return SignalProducer(values: producers).flatten(.merge)
	}
	
	/// Merges the given producers into a single `SignalProducer` that will emit
	/// all values from each of them, and complete when all of them have
	/// completed.
	public static func merge<S: SignalProducerProtocol where S.Value == Value, S.Error == Error>(_ producers: S...) -> SignalProducer<Value, Error> {
		return SignalProducer.merge(producers)
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Error == Value.Error {
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

	private func observeSwitchToLatest(_ observer: Observer<Value.Value, Error>, _ latestInnerDisposable: SerialDisposable) -> Disposable? {
		let state = Atomic(LatestState<Value, Error>())

		return self.observe { event in
			switch event {
			case let .next(innerProducer):
				innerProducer.startWithSignal { innerSignal, innerDisposable in
					state.modify { state in
						// When we replace the disposable below, this prevents
						// the generated Interrupted event from doing any work.
						state.replacingInnerSignal = true
					}

					latestInnerDisposable.innerDisposable = innerDisposable

					state.modify { state in
						state.replacingInnerSignal = false
						state.innerSignalComplete = false
					}

					innerSignal.observe { event in
						switch event {
						case .interrupted:
							// If interruption occurred as a result of a new
							// producer arriving, we don't want to notify our
							// observer.
							let original = state.modify { state in
								if !state.replacingInnerSignal {
									state.innerSignalComplete = true
								}
							}

							if !original.replacingInnerSignal && original.outerSignalComplete {
								observer.sendCompleted()
							}

						case .completed:
							let original = state.modify { state in
								state.innerSignalComplete = true
							}

							if original.outerSignalComplete {
								observer.sendCompleted()
							}

						case .next, .failed:
							observer.action(event)
						}
					}
				}
			case let .failed(error):
				observer.sendFailed(error)
			case .completed:
				let original = state.modify { state in
					state.outerSignalComplete = true
				}

				if original.innerSignalComplete {
					observer.sendCompleted()
				}
			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
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
			disposable += latestInnerDisposable

			self.startWithSignal { signal, signalDisposable in
				disposable += signalDisposable
				disposable += signal.observeSwitchToLatest(observer, latestInnerDisposable)
			}
		}
	}
}

private struct LatestState<Value, Error: ErrorProtocol> {
	var outerSignalComplete: Bool = false
	var innerSignalComplete: Bool = true
	
	var replacingInnerSignal: Bool = false
}


extension SignalProtocol {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` or any of the created producers fail, the returned signal
	/// will forward that failure immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, Error>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` fails, the returned signal will forward that failure
	/// immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, NoError>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` or any of the created signals emit an error, the returned
	/// signal will forward that error immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, Error>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If `signal` emits an error, the returned signal will forward that
	/// error immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, NoError>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}
}

extension SignalProtocol where Error == NoError {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created signals emit an error, the returned signal
	/// will forward that error immediately.
	public func flatMap<U, E>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, E>) -> Signal<U, E> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, NoError>) -> Signal<U, NoError> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created signals emit an error, the returned signal
	/// will forward that error immediately.
	public func flatMap<U, E>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, E>) -> Signal<U, E> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, NoError>) -> Signal<U, NoError> {
		return map(transform).flatten(strategy)
	}
}

extension SignalProducerProtocol {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` or any of the created producers fail, the returned producer
	/// will forward that failure immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` fails, the returned producer will forward that failure
	/// immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, NoError>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` or any of the created signals emit an error, the returned
	/// producer will forward that error immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If `self` emits an error, the returned producer will forward that
	/// error immediately.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, NoError>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}
}

extension SignalProducerProtocol where Error == NoError {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created producers fail, the returned producer will
	/// forward that failure immediately.
	public func flatMap<U, E>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, E>) -> SignalProducer<U, E> {
		return map(transform).flatten(strategy)
	}
	
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> SignalProducer<U, NoError>) -> SignalProducer<U, NoError> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// If any of the created signals emit an error, the returned
	/// producer will forward that error immediately.
	public func flatMap<U, E>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, E>) -> SignalProducer<U, E> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting signals (into a producer of values), according to the
	/// semantics of the given strategy.
	public func flatMap<U>(_ strategy: FlattenStrategy, transform: (Value) -> Signal<U, NoError>) -> SignalProducer<U, NoError> {
		return map(transform).flatten(strategy)
	}
}


extension SignalProtocol {
	/// Catches any failure that may occur on the input signal, mapping to a new
	/// producer that starts in its place.
	public func flatMapError<F>(_ handler: (Error) -> SignalProducer<Value, F>) -> Signal<Value, F> {
		return Signal { observer in
			self.observeFlatMapError(handler, observer, SerialDisposable())
		}
	}

	private func observeFlatMapError<F>(_ handler: (Error) -> SignalProducer<Value, F>, _ observer: Observer<Value, F>, _ serialDisposable: SerialDisposable) -> Disposable? {
		return self.observe { event in
			switch event {
			case let .next(value):
				observer.sendNext(value)
			case let .failed(error):
				handler(error).startWithSignal { signal, disposable in
					serialDisposable.innerDisposable = disposable
					signal.observe(observer)
				}
			case .completed:
				observer.sendCompleted()
			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducerProtocol {
	/// Catches any failure that may occur on the input producer, mapping to a
	/// new producer that starts in its place.
	public func flatMapError<F>(_ handler: (Error) -> SignalProducer<Value, F>) -> SignalProducer<Value, F> {
		return SignalProducer { observer, disposable in
			let serialDisposable = SerialDisposable()
			disposable += serialDisposable

			self.startWithSignal { signal, signalDisposable in
				serialDisposable.innerDisposable = signalDisposable

				_ = signal.observeFlatMapError(handler, observer, serialDisposable)
			}
		}
	}
}
