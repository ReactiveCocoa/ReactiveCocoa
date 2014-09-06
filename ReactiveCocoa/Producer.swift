//
//  Producer.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import swiftz_core

/// A stream that will begin generating Events when a Consumer is attached,
/// possibly performing some side effects in the process. Events are pushed to
/// the consumer as they are generated.
///
/// A corollary to this is that different Consumers may see a different timing
/// of Events, or even a different version of events altogether.
public struct Producer<T> {
	private let producerClosure: Consumer<T> -> ()

	/// Initializes a Producer that will run the given action whenever an
	/// Consumer is attached.
	public init(produce: Consumer<T> -> ()) {
		producerClosure = produce
	}

	/// Creates a Producer that will immediately complete.
	public static func empty() -> Producer<T> {
		return Producer { consumer in
			consumer.put(.Completed)
		}
	}

	/// Creates a Producer that will immediately yield a single value then
	/// complete.
	public static func single(value: T) -> Producer<T> {
		return Producer { consumer in
			consumer.put(.Next(Box(value)))
			consumer.put(.Completed)
		}
	}

	/// Creates a Producer that will immediately generate an error.
	public static func error(error: NSError) -> Producer<T> {
		return Producer { consumer in
			consumer.put(.Error(error))
		}
	}

	/// Creates a Producer that will never send any events.
	public static func never() -> Producer<T> {
		return Producer { _ in () }
	}

	/// Starts producing events for the given consumer, performing any side
	/// effects embedded within the Producer.
	///
	/// Optionally returns a Disposable which will cancel the work associated
	/// with event production, and prevent any further events from being sent.
	public func produce(consumer: Consumer<T>) -> Disposable {
		producerClosure(consumer)
		return consumer.disposable
	}

	/// Convenience function to invoke produce() with a Consumer that will
	/// pass values to the given closure.
	public func produce(consumer: Event<T> -> ()) -> Disposable {
		return produce(Consumer(consumer))
	}

	/// Convenience function to invoke produce() with a Consumer that has
	/// the given callbacks for each event type.
	public func produce(next: T -> (), error: NSError -> (), completed: () -> ()) -> Disposable {
		return produce(Consumer(next: next, error: error, completed: completed))
	}

	/// Maps over the elements of the Producer, accumulating a state along the
	/// way.
	///
	/// This is meant as a primitive operator from which more complex operators
	/// can be built.
	///
	/// Yielding a `nil` state at any point will stop evaluation of the original
	/// Producer, and dispose of it.
	///
	/// Returns a Producer of the mapped values.
	public func mapAccumulate<State, U>(initialState: State, _ f: (State, T) -> (State?, U)) -> Producer<U> {
		return Producer<U> { consumer in
			let state = Atomic(initialState)
			let disposable = self.produce { event in
				switch event {
				case let .Next(box):
					let (maybeState, newValue) = f(state.value, box.value)
					consumer.put(.Next(Box(newValue)))

					if let s = maybeState {
						state.value = s
					} else {
						consumer.put(.Completed)
					}

				case let .Error(error):
					consumer.put(.Error(error))

				case let .Completed:
					consumer.put(.Completed)
				}
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Merges a Producer of Producers into a single stream.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a producer of producers. Simply pass in the `identity` function.
	///
	/// Returns a Producer that will forward events from the original streams
	/// as they arrive.
	public func merge<U>(evidence: Producer<T> -> Producer<Producer<U>>) -> Producer<U> {
		return Producer<U> { consumer in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)

			let decrementInFlight: () -> () = {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					consumer.put(.Completed)
				}
			}

			let selfDisposable = evidence(self).produce { event in
				switch event {
				case let .Next(stream):
					inFlight.modify { $0 + 1 }

					let streamDisposable = SerialDisposable()
					disposable.addDisposable(streamDisposable)

					streamDisposable.innerDisposable = stream.value.produce { event in
						if event.isTerminating {
							streamDisposable.dispose()
							disposable.pruneDisposed()
						}

						switch event {
						case let .Completed:
							decrementInFlight()

						default:
							consumer.put(event)
						}
					}

				case let .Error(error):
					consumer.put(.Error(error))

				case let .Completed:
					decrementInFlight()
				}
			}

			consumer.disposable.addDisposable(selfDisposable)
		}
	}

	/// Switches on a Producer of Producers, forwarding events from the
	/// latest inner stream.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a producer of producers. Simply pass in the `identity` function.
	///
	/// Returns a Producer that will forward events only from the latest
	/// Producer sent upon the receiver.
	public func switchToLatest<U>(evidence: Producer<T> -> Producer<Producer<U>>) -> Producer<U> {
		return Producer<U> { consumer in
			let selfCompleted = Atomic(false)
			let latestCompleted = Atomic(false)

			let completeIfNecessary: () -> () = {
				if selfCompleted.value && latestCompleted.value {
					consumer.put(.Completed)
				}
			}

			let latestDisposable = SerialDisposable()
			consumer.disposable.addDisposable(latestDisposable)

			let selfDisposable = evidence(self).produce { event in
				switch event {
				case let .Next(stream):
					latestDisposable.innerDisposable = nil
					latestDisposable.innerDisposable = stream.value.produce { innerEvent in
						switch innerEvent {
						case let .Completed:
							latestCompleted.value = true
							completeIfNecessary()

						default:
							consumer.put(innerEvent)
						}
					}

				case let .Error(error):
					consumer.put(.Error(error))

				case let .Completed:
					selfCompleted.value = true
					completeIfNecessary()
				}
			}

			consumer.disposable.addDisposable(selfDisposable)
		}
	}

	/// Maps each value in the stream to a new value.
	public func map<U>(f: T -> U) -> Producer<U> {
		return mapAccumulate(()) { (_, value) in
			return ((), f(value))
		}
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
	public func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Producer<U> {
		return mapAccumulate(initialValue) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	/// Returns a stream that will yield the first `count` values from the
	/// receiver.
	public func take(count: Int) -> Producer<T> {
		if count == 0 {
			return .empty()
		}

		return mapAccumulate(0) { (n, value) in
			let newN: Int? = (n + 1 < count ? n + 1 : nil)
			return (newN, value)
		}
	}

	/// Returns a stream that will yield values from the receiver while `pred`
	/// remains `true`.
	public func takeWhile(pred: T -> Bool) -> Producer<T> {
		return self
			.mapAccumulate(true) { (taking, value) in
				if taking && pred(value) {
					return (true, .single(value))
				} else {
					return (nil, .empty())
				}
			}
			.merge(identity)
	}

	/// Combines each value in the stream with its preceding value, starting
	/// with `initialValue`.
	public func combinePrevious(initialValue: T) -> Producer<(T, T)> {
		return mapAccumulate(initialValue) { (previous, current) in
			return (current, (previous, current))
		}
	}

	/// Returns a stream that will skip the first `count` values from the
	/// receiver, then forward everything afterward.
	public func skip(count: Int) -> Producer<T> {
		return self
			.mapAccumulate(0) { (n, value) in
				if n >= count {
					return (count, .single(value))
				} else {
					return (n + 1, .empty())
				}
			}
			.merge(identity)
	}

	/// Returns a stream that will skip values from the receiver while `pred`
	/// remains `true`, then forward everything afterward.
	public func skipWhile(pred: T -> Bool) -> Producer<T> {
		return self
			.mapAccumulate(true) { (skipping, value) in
				if !skipping || !pred(value) {
					return (false, .single(value))
				} else {
					return (true, .empty())
				}
			}
			.merge(identity)
	}

	/// Returns a Promise that will, when started, produce one event from the
	/// receiver then cancel production.
	public func first() -> Promise<Event<T>> {
		return Promise { sink in
			self.take(1).produce(Consumer(sink))
			return ()
		}
	}

	/// Returns a Promise that will start event production, then yield an Event
	/// which indicates whether production succeeded, or failed with an error.
	public func last() -> Promise<Event<()>> {
		return ignoreValues().first()
	}

	/// Starts producing events, setting the current value of `property` to each
	/// value yielded by the receiver.
	///
	/// The stream must not produce an `Error` event when bound to a property.
	///
	/// Optionally returns a Disposable which can be used to cancel the binding.
	public func bindTo(property: SignalingProperty<T>) -> Disposable {
		return self.produce { event in
			switch event {
			case let .Next(box):
				property.put(box.value)

			case let .Error(error):
				assert(false)

			default:
				break
			}
		}
	}

	/// Preserves only the values of the stream that pass the given predicate.
	public func filter(pred: T -> Bool) -> Producer<T> {
		return self
			.map { value -> Producer<T> in
				if pred(value) {
					return .single(value)
				} else {
					return .empty()
				}
			}
			.merge(identity)
	}

	/// Skips all consecutive, repeating values in the stream, forwarding only
	/// the first occurrence.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            values which are `Equatable`. Simply pass in the `identity`
	///            function.
	public func skipRepeats<U: Equatable>(evidence: Producer<T> -> Producer<U>) -> Producer<U> {
		return evidence(self)
			.mapAccumulate(nil) { (maybePrevious: U?, current: U) -> (U??, Producer<U>) in
				if let previous = maybePrevious {
					if current == previous {
						return (current, .empty())
					}
				}

				return (current, .single(current))
			}
			.merge(identity)
	}

	/// Brings the stream events into the monad, allowing them to be manipulated
	/// just like any other value.
	public func materialize() -> Producer<Event<T>> {
		return Producer<Event<T>> { consumer in
			let disposable = self.produce { event in
				consumer.put(.Next(Box(event)))

				if event.isTerminating {
					consumer.put(.Completed)
				}
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// The inverse of `materialize`, this will translate a stream of `Event`
	/// _values_ into a stream of those events themselves.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            a stream of `Event`s. Simply pass in the `identity` function.
	public func dematerialize<U>(evidence: Producer<T> -> Producer<Event<U>>) -> Producer<U> {
		return Producer<U> { consumer in
			let disposable = evidence(self).produce { event in
				switch event {
				case let .Next(eventBox):
					consumer.put(eventBox.value)

				case let .Error(error):
					consumer.put(.Error(error))

				case let .Completed:
					consumer.put(.Completed)
				}
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Creates and attaches to a new Producer when an error occurs.
	public func catch(f: NSError -> Producer<T>) -> Producer<T> {
		return Producer { consumer in
			let serialDisposable = SerialDisposable()
			consumer.disposable.addDisposable(serialDisposable)

			serialDisposable.innerDisposable = self.produce { event in
				switch event {
				case let .Error(error):
					let newStream = f(error)
					serialDisposable.innerDisposable = newStream.produce(consumer)

				default:
					consumer.put(event)
				}
			}
		}
	}

	private func retry(behavior: (NSError, Int) -> Promise<Bool>, consumer: Consumer<T>, attempt: Int, disposable: SerialDisposable) {
		disposable.innerDisposable = self.produce { event in
			switch event {
			case let .Error(error):
				let promise = behavior(error, attempt)

				disposable.innerDisposable = promise.signal.observe { shouldRetry in
					if let shouldRetry = shouldRetry {
						if shouldRetry {
							self.retry(behavior, consumer: consumer, attempt: attempt + 1, disposable: disposable)
						} else {
							consumer.put(.Error(error))
						}
					}
				}

				promise.start()

			default:
				consumer.put(event)
			}
		}
	}

	/// Optionally retries when an error occurs.
	///
	/// behavior - A function accepting the error that occurred, and the retry
	///            attempt that this constitutes (starting at 1). When the
	///            returned Promise yields `true`, the receiver will be started
	///            again. If it yields `false`, the error will continue
	///            propagating.
	///
	/// Returns a Producer that will pass through the receiver's events until
	/// an error occurs, then pass through the events from any retry attempts.
	/// If retrying is declined at any point, the Producer will send the error.
	public func retry(behavior: (NSError, Int) -> Promise<Bool>) -> Producer<T> {
		return Producer { consumer in
			let serialDisposable = SerialDisposable()
			consumer.disposable.addDisposable(serialDisposable)

			self.retry(behavior, consumer: consumer, attempt: 1, disposable: serialDisposable)
		}
	}

	/// Discards all values in the stream, preserving only `Error` and
	/// `Completed` events.
	public func ignoreValues() -> Producer<()> {
		return Producer<()> { consumer in
			let disposable = self.produce { event in
				switch event {
				case let .Next(value):
					break

				case let .Error(error):
					consumer.put(.Error(error))

				case let .Completed:
					consumer.put(.Completed)
				}
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Performs the given action whenever the Producer yields an Event.
	public func doEvent(action: Event<T> -> ()) -> Producer<T> {
		return Producer { consumer in
			let disposable = self.produce { event in
				action(event)
				consumer.put(event)
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Performs the given action whenever event production for a single
	/// consumer is disposed of (whether it completed successfully, terminated
	/// from an error, or was manually disposed).
	public func doDisposed(action: () -> ()) -> Producer<T> {
		return Producer { consumer in
			consumer.disposable.addDisposable(ActionDisposable(action))
			consumer.disposable.addDisposable(self.produce(consumer))
		}
	}

	/// Performs the work of event production on the given Scheduler.
	///
	/// This implies that any side effects embedded in the receiver will be
	/// performed on the given Scheduler as well.
	///
	/// Values may still be sent upon other schedulers—this merely affects how
	/// the `produce` method is invoked.
	public func produceOn(scheduler: Scheduler) -> Producer<T> {
		return Producer { consumer in
			let disposable = self.produce { event in
				scheduler.schedule { consumer.put(event) }
				return ()
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Concatenates `stream` after the receiver.
	public func concat(stream: Producer<T>) -> Producer<T> {
		return Producer { consumer in
			let serialDisposable = SerialDisposable()
			consumer.disposable.addDisposable(serialDisposable)

			serialDisposable.innerDisposable = self.produce { event in
				switch event {
				case let .Completed:
					serialDisposable.innerDisposable = stream.produce(consumer)

				default:
					consumer.put(event)
				}
			}
		}
	}

	/// Waits for the receiver to complete successfully, then forwards only the
	/// last `count` values.
	public func takeLast(count: Int) -> Producer<T> {
		return Producer { consumer in
			let values: Atomic<[T]> = Atomic([])
			let disposable = self.produce { event in
				switch event {
				case let .Next(box):
					values.modify { (var arr) in
						arr.append(box.value)
						while arr.count > count {
							arr.removeAtIndex(0)
						}

						return arr
					}

				case let .Completed:
					for v in values.value {
						consumer.put(.Next(Box(v)))
					}

					consumer.put(.Completed)

				default:
					consumer.put(event)
				}
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Combines all of the values in the stream.
	///
	/// Returns a Producer which will send the single, aggregated value when
	/// the receiver completes.
	public func aggregate<U>(initialValue: U, _ f: (U, T) -> U) -> Producer<U> {
		let scanned = scan(initialValue, f)

		return Producer<U>.single(initialValue)
			.concat(scanned)
			.takeLast(1)
	}

	/// Waits for the receiver to complete successfully, then forwards
	/// a Sequence of all the values that were produced.
	public func collect() -> Producer<SequenceOf<T>> {
		return self
			.aggregate([]) { (var values, current) in
				values.append(current)
				return values
			}
			.map { SequenceOf($0) }
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Error` events are always scheduled immediately.
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> Producer<T> {
		return Producer { consumer in
			let disposable = self.produce { event in
				switch event {
				case let .Error:
					scheduler.schedule {
						consumer.put(event)
					}

				default:
					scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) {
						consumer.put(event)
					}
				}
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Yields all events on the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func deliverOn(scheduler: Scheduler) -> Producer<T> {
		return Producer { consumer in
			let disposable = self.produce { event in
				scheduler.schedule { consumer.put(event) }
				return ()
			}

			consumer.disposable.addDisposable(disposable)
		}
	}

	/// Yields `error` after the given interval if the receiver has not yet
	/// completed by that point.
	public func timeoutWithError(error: NSError, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> Producer<T> {
		return Producer { consumer in
			let schedulerDisposable = scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) {
				consumer.put(.Error(error))
			}

			consumer.disposable.addDisposable(schedulerDisposable)

			let selfDisposable = self.produce(consumer)
			consumer.disposable.addDisposable(selfDisposable)
		}
	}

	/// Performs the given action upon each value in the receiver, bailing out
	/// with an error if it returns `false`.
	public func try(f: (T, NSErrorPointer) -> Bool) -> Producer<T> {
		return tryMap { (value, error) in f(value, error) ? value : nil }
	}

	/// Attempts to map each value in the receiver, bailing out with an error if
	/// a given mapping is `nil`.
	public func tryMap<U>(f: (T, NSErrorPointer) -> U?) -> Producer<U> {
		return tryMap { value -> Result<U> in
			var error: NSError?
			let maybeValue = f(value, &error)

			if let v = maybeValue {
				return .Value(Box(v))
			} else {
				return .Error(error.orDefault(RACError.Empty.error))
			}
		}
	}

	/// Attempts to map each value in the receiver, bailing out with an error if
	/// a given mapping fails.
	public func tryMap<U>(f: T -> Result<U>) -> Producer<U> {
		return self
			.map { value in
				switch f(value) {
				case let .Value(box):
					return .single(box.value)

				case let .Error(error):
					return .error(error)
				}
			}
			.merge(identity)
	}
}
