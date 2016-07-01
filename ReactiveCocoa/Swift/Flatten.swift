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
	case merge

	/// The producers should be concatenated, so that their values are sent in the
	/// order of the producers themselves.
	///
	/// The resulting producer will complete only when all inputs have completed.
	case concat

	/// Only the events from the latest input producer should be considered for
	/// the output. Any producers received before that point will be disposed of.
	///
	/// The resulting producer will complete only when the producer-of-producers and
	/// the latest producer has completed.
	case latest
}


extension SignalProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` or an active inner producer fails, the returned signal will
	/// forward that failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
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
	/// If an active inner producer fails, the returned signal will forward that
	/// failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
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
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
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
	/// If `signal` fails, the returned signal will forward that failure
	/// immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` or an active inner producer fails, the returned producer will
	/// forward that failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
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
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If an active inner producer fails, the returned producer will forward that
	/// failure immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == NoError, Value.Error == NoError {
	/// Flattens the inner producers sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
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
	/// If `signal` fails, the returned signal will forward that failure
	/// immediately.
	///
	/// `Interrupted` events on inner producers will be treated like `Completed`
	/// events on inner producers.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.promoteErrors(Error.self) }
	}
}

extension SignalProtocol where Value: SignalProtocol, Error == Value.Error {
	/// Flattens the inner signals sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// If `signal` or an active inner signal emits an error, the returned
	/// signal will forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
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
	/// If an active inner signal emits an error, the returned signal will
	/// forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
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
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
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
	/// If `signal` emits an error, the returned signal will forward
	/// that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
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
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` or an active inner signal emits an error, the returned
	/// producer will forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If an active inner signal emits an error, the returned producer will
	/// forward that error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteErrors(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Error == NoError, Value.Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.map(SignalProducer.init)
			.flatten(strategy)
	}
}

extension SignalProducerProtocol where Value: SignalProtocol, Value.Error == NoError {
	/// Flattens the inner signals sent upon `producer` (into a single producer of
	/// values), according to the semantics of the given strategy.
	///
	/// If `producer` emits an error, the returned producer will forward that
	/// error immediately.
	///
	/// `Interrupted` events on inner signals will be treated like `Completed`
	/// events on inner signals.
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
			self.observeConcat(relayObserver)
		}
	}

	private func observeConcat(_ observer: Observer<Value.Value, Error>, producerDisposing trigger: Signal<(), NoError>? = nil) {
		let state = ConcatState(observer: observer)

		trigger?.observeCompleted {
			state.interrupt()
		}

		self.observe { event in
			switch event {
			case let .next(value):
				state.enqueueSignalProducer(value.producer)

			case let .failed(error):
				state.interrupt(error: error)

			case .completed:
				// Add one last producer to the queue, whose sole job is to
				// "turn out the lights" by completing `observer`.
				state.enqueueCompletionProducer()

			case .interrupted:
				state.interrupt()
			}
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
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
		return SignalProducer<Value.Value, Error> { observer, disposalTrigger in
			self.startWithSignal { signal, interrupter in
				disposalTrigger.observeTerminated(interrupter)
				signal.observeConcat(observer, producerDisposing: disposalTrigger)
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

	/// The active producer, if any, and the producers waiting to be started.
	let queuedSignalProducers: Atomic<[SignalProducer<Value, Error>]> = Atomic([])

	var currentProducerDisposable: Disposable?

	init(observer: Signal<Value, Error>.Observer) {
		self.observer = observer
	}

	func enqueueSignalProducer(_ producer: SignalProducer<Value, Error>) {
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
		signalProducer.startWithSignal { signal, interrupter in
			currentProducerDisposable = interrupter

			signal.observe { event in
				switch event {
				case .completed, .interrupted:
					self.currentProducerDisposable = nil

					if let nextSignalProducer = self.dequeueSignalProducer() {
						self.startNextSignalProducer(nextSignalProducer)
					}

				case .next, .failed:
					self.observer.action(event)
				}
			}
		}
	}

	func interrupt(error: Error? = nil) {
		queuedSignalProducers.modify { queue in
			queue.removeAll()
		}

		if let error = error {
			observer.sendFailed(error)
		} else {
			observer.sendInterrupted()
		}

		currentProducerDisposable?.dispose()
	}

	func enqueueCompletionProducer() {
		enqueueSignalProducer(SignalProducer.empty.on(completed: {
			self.observer.sendCompleted()
			self.currentProducerDisposable?.dispose()
		}))
	}
}

extension SignalProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Merges a `signal` of SignalProducers down into a single signal, biased toward the producer
	/// added earlier. Returns a Signal that will forward events from the inner producers as they arrive.
	private func merge() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { relayObserver in
			self.observeMerge(relayObserver)
		}
	}

	private func observeMerge(_ observer: Observer<Value.Value, Error>, producerDisposing trigger: Signal<(), NoError>? = nil) {
		let inFlight = Atomic(1)

		let interrupters = Atomic<Bag<Disposable>?>(Bag())

		func cleanup() {
			let observers = interrupters.swap(nil)
			observers?.forEach { interrupter in
				interrupter.dispose()
			}
		}

		func decrementInFlight() {
			let orig = inFlight.modify { $0 -= 1 }
			if orig == 1 {
				observer.sendCompleted()
				cleanup()
			}
		}

		trigger?.observeCompleted {
			cleanup()
		}

		self.observe { event in
			switch event {
			case let .next(producer):
				producer.startWithSignal { innerSignal, interrupter in
					inFlight.modify { $0 += 1 }

					var token: RemovalToken?
					interrupters.modify { bag in
						token = bag?.insert(interrupter)
					}

					innerSignal.observe { event in
						switch event {
						case .completed, .interrupted:
							interrupters.modify { bag in
								_ = token.map { bag?.remove(using: $0) }
							}
							decrementInFlight()

						case .next, .failed:
							observer.action(event)
						}
					}
				}

			case let .failed(error):
				observer.sendFailed(error)
				cleanup()

			case .completed:
				decrementInFlight()

			case .interrupted:
				observer.sendInterrupted()
				cleanup()
			}
		}
	}
}

extension SignalProducerProtocol where Value: SignalProducerProtocol, Error == Value.Error {
	/// Merges a `signal` of SignalProducers down into a single signal, biased toward the producer
	/// added earlier. Returns a Signal that will forward events from the inner producers as they arrive.
	private func merge() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { relayObserver, disposalTrigger in
			self.startWithSignal { signal, interrupter in
				disposalTrigger.observeTerminated(interrupter)
				signal.observeMerge(relayObserver, producerDisposing: disposalTrigger)
			}
		}
	}
}

extension SignalProtocol {
	/// Merges the given signals into a single `Signal` that will emit all values
	/// from each of them, and complete when all of them have completed.
	public static func merge<Seq: Sequence, S: SignalProtocol where S.Value == Value, S.Error == Error, Seq.Iterator.Element == S>(_ signals: Seq) -> Signal<Value, Error> {
		let producer = SignalProducer<S, Error>(values: signals)
		var result: Signal<Value, Error>!

		producer.startWithSignal { signal, _ in
			result = signal.flatten(.merge)
		}

		return result
	}
	
	/// Merges the given signals into a single `Signal` that will emit all values
	/// from each of them, and complete when all of them have completed.
	public static func merge<S: SignalProtocol where S.Value == Value, S.Error == Error>(_ signals: S...) -> Signal<Value, Error> {
		return Signal.merge(signals)
	}
}

extension SignalProducerProtocol {
	/// Merges the given producers into a single `SignalProducer` that will emit all values
	/// from each of them, and complete when all of them have completed.
	public static func merge<Seq: Sequence, S: SignalProducerProtocol where S.Value == Value, S.Error == Error, Seq.Iterator.Element == S>(_ producers: Seq) -> SignalProducer<Value, Error> {
		return SignalProducer(values: producers).flatten(.merge)
	}
	
	/// Merges the given producers into a single `SignalProducer` that will emit all values
	/// from each of them, and complete when all of them have completed.
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
			self.observeSwitchToLatest(observer)
		}
	}

	private func observeSwitchToLatest(_ observer: Observer<Value.Value, Error>, producerDisposing trigger: Signal<(), NoError>? = nil) {
		let state = Atomic(LatestState<Value, Error>())

		func cleanup() {
			var interrupter: Disposable?

			state.modify { latestState in
				swap(&interrupter, &latestState.interrupter)
			}

			interrupter?.dispose()
		}

		trigger?.observeCompleted(cleanup)

		return self.observe { event in
			switch event {
			case let .next(innerProducer):
				innerProducer.startWithSignal { innerSignal, interrupter in
					var oldDisposable: Disposable?

					state.modify { state in
						// When we replace the disposable below, this prevents the
						// generated Interrupted event from doing any work.
						state.replacingInnerSignal = true

						oldDisposable = interrupter
						swap(&state.interrupter, &oldDisposable)
					}

					oldDisposable?.dispose()

					state.modify { state in
						state.replacingInnerSignal = false
						state.innerSignalComplete = false
					}

					innerSignal.observe { event in
						switch event {
						case .interrupted:
							// If interruption occurred as a result of a new producer
							// arriving, we don't want to notify our observer.
							let original = state.modify { state in
								if !state.replacingInnerSignal {
									state.innerSignalComplete = true
								}
							}

							if !original.replacingInnerSignal && original.outerSignalComplete {
								observer.sendCompleted()
								cleanup()
							}

						case .completed:
							let original = state.modify { state in
								state.innerSignalComplete = true
							}

							if original.outerSignalComplete {
								observer.sendCompleted()
								cleanup()
							}

						case .next:
							observer.action(event)

						case .failed:
							observer.action(event)
							cleanup()
						}
					}
				}
			case let .failed(error):
				observer.sendFailed(error)
				cleanup()

			case .completed:
				let original = state.modify { state in
					state.outerSignalComplete = true
				}

				if original.innerSignalComplete {
					observer.sendCompleted()
					cleanup()
				}

			case .interrupted:
				observer.sendInterrupted()
				cleanup()
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
		return SignalProducer<Value.Value, Error> { observer, disposalTrigger in
			self.startWithSignal { signal, interrupter in
				disposalTrigger.observeTerminated(interrupter)
				signal.observeSwitchToLatest(observer, producerDisposing: disposalTrigger)
			}
		}
	}
}

private struct LatestState<Value, Error: ErrorProtocol> {
	var outerSignalComplete: Bool = false
	var innerSignalComplete: Bool = true
	
	var replacingInnerSignal: Bool = false
	var interrupter: Disposable?
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
	/// Catches any failure that may occur on the input signal, mapping to a new producer
	/// that starts in its place.
	public func flatMapError<F>(_ handler: (Error) -> SignalProducer<Value, F>) -> Signal<Value, F> {
		return Signal { observer in
			self.observeFlatMapError(handler, observer)
		}
	}

	private func observeFlatMapError<F>(_ handler: (Error) -> SignalProducer<Value, F>, _ observer: Observer<Value, F>, producerDisposing trigger: Signal<(), NoError>? = nil) {
		return self.observe { event in
			switch event {
			case let .next(value):
				observer.sendNext(value)
			case let .failed(error):
				handler(error).startWithSignal { signal, interrupter in
					trigger?.observeTerminated(interrupter)
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
	/// Catches any failure that may occur on the input producer, mapping to a new producer
	/// that starts in its place.
	public func flatMapError<F>(_ handler: (Error) -> SignalProducer<Value, F>) -> SignalProducer<Value, F> {
		return SignalProducer { observer, disposalTrigger in
			self.startWithSignal { signal, interrupter in
				disposalTrigger.observeTerminated(interrupter)
				signal.observeFlatMapError(handler, observer, producerDisposing: disposalTrigger)
			}
		}
	}
}
