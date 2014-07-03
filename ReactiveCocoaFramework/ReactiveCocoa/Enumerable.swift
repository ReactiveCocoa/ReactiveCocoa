//
//  Enumerable.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

func _dummyNext(value: Any) {}
func _dummyError(error: NSError) {}
func _dummyCompleted() {}

/// Receives events from an Enumerable.
class Enumerator<T>: Sink {
	typealias Element = Event<T>

	let _sink: Atomic<SinkOf<Element>?>

	/// A list of Disposables to dispose of when the enumerator receives
	/// a terminating event, or if enumeration is canceled.
	let disposable = CompositeDisposable()

	/// Initializes an Enumerator that will forward events to the given sink.
	init<S: Sink where S.Element == Event<T>>(_ sink: S) {
		_sink = Atomic(SinkOf(sink))

		// This is redundant with the behavior of put() in case of
		// a terminating event, but ensures that we get rid of the closure
		// upon cancellation as well.
		disposable.addDisposable {
			self._sink.value = nil
		}
	}

	/// Initializes an Enumerator that will perform the given action whenever an
	/// event is received.
	convenience init(put: Event<T> -> ()) {
		self.init(SinkOf(put))
	}

	/// Initializes an Enumerator with zero or more different callbacks, based
	/// on the type of Event received.
	convenience init(next: T -> () = _dummyNext, error: NSError -> () = _dummyError, completed: () -> () = _dummyCompleted) {
		self.init(SinkOf<Element> { event in
			switch event {
			case let .Next(value):
				next(value)

			case let .Error(err):
				error(err)

			case let .Completed:
				completed()
			}
		})
	}

	func put(event: Event<T>) {
		let oldSink = _sink.modify { s in
			if event.isTerminating {
				return nil
			} else {
				return s
			}
		}
		
		oldSink?.put(event)

		if event.isTerminating {
			disposable.dispose()
		}
	}
}

/// A pull-driven stream that executes work when an enumerator is attached.
class Enumerable<T> {
	@final let _enumerate: Enumerator<T> -> ()

	/// Initializes an Enumerable that will run the given action whenever an
	/// Enumerator is attached.
	init(enumerate: Enumerator<T> -> ()) {
		_enumerate = enumerate
	}

	/// Creates an Enumerable that will immediately complete.
	@final class func empty() -> Enumerable<T> {
		return Enumerable { enumerator in
			enumerator.put(.Completed)
		}
	}

	/// Creates an Enumerable that will immediately yield a single value then
	/// complete.
	@final class func single(value: T) -> Enumerable<T> {
		return Enumerable { enumerator in
			enumerator.put(.Next(Box(value)))
			enumerator.put(.Completed)
		}
	}

	/// Creates an Enumerable that will immediately generate an error.
	@final class func error(error: NSError) -> Enumerable<T> {
		return Enumerable { enumerator in
			enumerator.put(.Error(error))
		}
	}

	/// Creates an Enumerable that will never send any events.
	@final class func never() -> Enumerable<T> {
		return Enumerable { _ in () }
	}

	/// Starts a new enumeration pass, performing any side effects embedded
	/// within the Enumerable.
	///
	/// Optionally returns a Disposable which will cancel the work associated
	/// with the enumeration, and prevent any further events from being sent.
	@final func enumerate(enumerator: Enumerator<T>) -> Disposable {
		_enumerate(enumerator)
		return enumerator.disposable
	}

	/// Convenience function to invoke enumerate() with an Enumerator that will
	/// pass values to the given closure.
	@final func enumerate(enumerator: Event<T> -> ()) -> Disposable {
		return enumerate(Enumerator(enumerator))
	}

	/// Convenience function to invoke enumerate() with an Enumerator that has
	/// the given callbacks for each event type.
	@final func enumerate(next: T -> (), error: NSError -> (), completed: () -> ()) -> Disposable {
		return enumerate(Enumerator(next: next, error: error, completed: completed))
	}

	/// Maps over the elements of the Enumerable, accumulating a state along the
	/// way.
	///
	/// This is meant as a primitive operator from which more complex operators
	/// can be built.
	///
	/// Returns an Enumerable of the mapped values.
	@final func mapAccumulate<S, U>(initialState: S, _ f: (S, T) -> (S?, U)) -> Enumerable<U> {
		return Enumerable<U> { enumerator in
			let state = Atomic(initialState)
			let disposable = self.enumerate { event in
				switch event {
				case let .Next(value):
					let (maybeState, newValue) = f(state, value)
					enumerator.put(.Next(Box(newValue)))

					if let s = maybeState {
						state.value = s
					} else {
						enumerator.put(.Completed)
					}

				case let .Error(error):
					enumerator.put(.Error(error))

				case let .Completed:
					enumerator.put(.Completed)
				}
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Merges an Enumerable of Enumerables into a single stream.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream-of-streams. Simply pass in the `identity` function.
	///
	/// Returns an Enumerable that will forward events from the original streams
	/// as they arrive.
	@final func merge<U>(evidence: Enumerable<T> -> Enumerable<Enumerable<U>>) -> Enumerable<U> {
		return Enumerable<U> { enumerator in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)

			func decrementInFlight() {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					enumerator.put(.Completed)
				}
			}

			let selfDisposable = evidence(self).enumerate { event in
				switch event {
				case let .Next(stream):
					let streamDisposable = SerialDisposable()
					disposable.addDisposable(streamDisposable)

					streamDisposable.innerDisposable = stream.value.enumerate { event in
						if event.isTerminating {
							disposable.removeDisposable(streamDisposable)
						}

						switch event {
						case let .Completed:
							decrementInFlight()

						default:
							enumerator.put(event)
						}
					}

				case let .Error(error):
					enumerator.put(.Error(error))

				case let .Completed:
					decrementInFlight()
				}
			}

			enumerator.disposable.addDisposable(selfDisposable)
		}
	}

	/// Switches on an Enumerable of Enumerables, forwarding events from the
	/// latest inner stream.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream-of-streams. Simply pass in the `identity` function.
	///
	/// Returns an Enumerable that will forward events only from the latest
	/// Enumerable sent upon the receiver.
	@final func switchToLatest<U>(evidence: Enumerable<T> -> Enumerable<Enumerable<U>>) -> Enumerable<U> {
		return Enumerable<U> { enumerator in
			let selfCompleted = Atomic(false)
			let latestCompleted = Atomic(false)

			func completeIfNecessary() {
				if selfCompleted.value && latestCompleted.value {
					enumerator.put(.Completed)
				}
			}

			let latestDisposable = SerialDisposable()
			enumerator.disposable.addDisposable(latestDisposable)

			let selfDisposable = evidence(self).enumerate { event in
				switch event {
				case let .Next(stream):
					latestDisposable.innerDisposable = nil
					latestDisposable.innerDisposable = stream.value.enumerate { innerEvent in
						switch innerEvent {
						case let .Completed:
							latestCompleted.value = true
							completeIfNecessary()

						default:
							enumerator.put(innerEvent)
						}
					}

				case let .Error(error):
					enumerator.put(.Error(error))

				case let .Completed:
					selfCompleted.value = true
					completeIfNecessary()
				}
			}

			enumerator.disposable.addDisposable(selfDisposable)
		}
	}

	/// Maps each value in the stream to a new value.
	@final func map<U>(f: T -> U) -> Enumerable<U> {
		return mapAccumulate(()) { (_, value) in
			return ((), f(value))
		}
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
	@final func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Enumerable<U> {
		return mapAccumulate(initialValue) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	/// Returns a stream that will yield the first `count` values from the
	/// receiver.
	@final func take(count: Int) -> Enumerable<T> {
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
	@final func takeWhile(pred: T -> Bool) -> Enumerable<T> {
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
	@final func combinePrevious(initialValue: T) -> Enumerable<(T, T)> {
		return mapAccumulate(initialValue) { (previous, current) in
			return (current, (previous, current))
		}
	}

	/// Returns a stream that will skip the first `count` values from the
	/// receiver, then forward everything afterward.
	@final func skip(count: Int) -> Enumerable<T> {
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
	@final func skipWhile(pred: T -> Bool) -> Enumerable<T> {
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

	/// Starts an enumeration pass, then blocks indefinitely, waiting for
	/// a single event to be generated.
	@final func first() -> Event<T> {
		let cond = NSCondition()
		cond.name = "com.github.ReactiveCocoa.Enumerable.first"

		var event: Event<T>? = nil
		take(1).enumerate { ev in
			withLock(cond) {
				event = ev
				cond.signal()
			}
		}

		return withLock(cond) {
			while event == nil {
				cond.wait()
			}

			return event!
		}
	}

	/// Starts an enumeration pass, and blocks indefinitely waiting for it to
	/// complete.
	///
	/// Returns an Event which indicates whether enumeration succeeded or failed
	/// with an error.
	@final func waitUntilCompleted() -> Event<()> {
		return ignoreValues().first()
	}

	/// Starts an enumeration pass, setting the current value of `property` to
	/// each value yielded by the receiver.
	///
	/// The stream must not generate an `Error` event when bound to a property.
	///
	/// Optionally returns a Disposable which can be used to cancel the binding.
	@final func bindToProperty(property: SignalingProperty<T>) -> Disposable {
		return self.enumerate { event in
			switch event {
			case let .Next(value):
				property.current = value

			case let .Error(error):
				assert(false)

			default:
				break
			}
		}
	}

	/// Preserves only the values of the stream that pass the given predicate.
	@final func filter(pred: T -> Bool) -> Enumerable<T> {
		return self
			.map { value -> Enumerable<T> in
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
	@final func skipRepeats<U: Equatable>(evidence: Enumerable<T> -> Enumerable<U>) -> Enumerable<U> {
		return evidence(self)
			.mapAccumulate(nil) { (maybePrevious: U?, current: U) -> (U??, Enumerable<U>) in
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
	@final func materialize() -> Enumerable<Event<T>> {
		return Enumerable<Event<T>> { enumerator in
			let disposable = self.enumerate { event in
				enumerator.put(.Next(Box(event)))

				if event.isTerminating {
					enumerator.put(.Completed)
				}
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// The inverse of `materialize`, this will translate a stream of `Event`
	/// _values_ into a stream of those events themselves.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            a stream of `Event`s. Simply pass in the `identity` function.
	@final func dematerialize<U>(evidence: Enumerable<T> -> Enumerable<Event<U>>) -> Enumerable<U> {
		return Enumerable<U> { enumerator in
			let disposable = evidence(self).enumerate { event in
				switch event {
				case let .Next(innerEvent):
					enumerator.put(innerEvent)

				case let .Error(error):
					enumerator.put(.Error(error))

				case let .Completed:
					enumerator.put(.Completed)
				}
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Creates and attaches to a new Enumerable when an error occurs.
	@final func catch(f: NSError -> Enumerable<T>) -> Enumerable<T> {
		return Enumerable { enumerator in
			let serialDisposable = SerialDisposable()
			enumerator.disposable.addDisposable(serialDisposable)

			serialDisposable.innerDisposable = self.enumerate { event in
				switch event {
				case let .Error(error):
					let newStream = f(error)
					serialDisposable.innerDisposable = newStream.enumerate(enumerator)

				default:
					enumerator.put(event)
				}
			}
		}
	}

	/// Discards all values in the stream, preserving only `Error` and
	/// `Completed` events.
	@final func ignoreValues() -> Enumerable<()> {
		return Enumerable<()> { enumerator in
			let disposable = self.enumerate { event in
				switch event {
				case let .Next(value):
					break

				case let .Error(error):
					enumerator.put(.Error(error))

				case let .Completed:
					enumerator.put(.Completed)
				}
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Performs the given action whenever the Enumerable yields an Event.
	@final func doEvent(action: Event<T> -> ()) -> Enumerable<T> {
		return Enumerable { enumerator in
			let disposable = self.enumerate { event in
				action(event)
				enumerator.put(event)
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Performs the given action whenever an enumeration pass is disposed of
	/// (whether it completed successfully, terminated from an error, or was
	/// manually disposed).
	@final func doDisposed(action: () -> ()) -> Enumerable<T> {
		return Enumerable { enumerator in
			enumerator.disposable.addDisposable(ActionDisposable(action))
			enumerator.disposable.addDisposable(self.enumerate(enumerator))
		}
	}

	/// Begins enumerating the receiver on the given Scheduler.
	///
	/// This implies that any side effects embedded in the receiver will be
	/// performed on the given Scheduler as well.
	///
	/// Values may still be sent upon other schedulers—this merely affects how
	/// the `enumerate` method is invoked.
	@final func enumerateOn(scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { enumerator in
			let disposable = self.enumerate { event in
				scheduler.schedule { enumerator.put(event) }
				return ()
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Concatenates `stream` after the receiver.
	@final func concat(stream: Enumerable<T>) -> Enumerable<T> {
		return Enumerable { enumerator in
			let serialDisposable = SerialDisposable()
			enumerator.disposable.addDisposable(serialDisposable)

			serialDisposable.innerDisposable = self.enumerate { event in
				switch event {
				case let .Completed:
					serialDisposable.innerDisposable = stream.enumerate(enumerator)

				default:
					enumerator.put(event)
				}
			}
		}
	}

	/// Waits for the receiver to complete successfully, then forwards only the
	/// last `count` values.
	@final func takeLast(count: Int) -> Enumerable<T> {
		return Enumerable { enumerator in
			let values: Atomic<T[]> = Atomic([])
			let disposable = self.enumerate { event in
				switch event {
				case let .Next(value):
					values.modify { (var arr) in
						arr.append(value)
						while arr.count > count {
							arr.removeAtIndex(0)
						}

						return arr
					}

				case let .Completed:
					for v in values.value {
						enumerator.put(.Next(Box(v)))
					}

					enumerator.put(.Completed)

				default:
					enumerator.put(event)
				}
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Combines all of the values in the stream.
	///
	/// Returns an Enumerable which will send the single, aggregated value when
	/// the receiver completes.
	@final func aggregate<U>(initialValue: U, _ f: (U, T) -> U) -> Enumerable<U> {
		let scanned = scan(initialValue, f)

		return Enumerable<U>.single(initialValue)
			.concat(scanned)
			.takeLast(1)
	}

	/// Waits for the receiver to complete successfully, then forwards
	/// a Sequence of all the values that were enumerated.
	@final func collect() -> Enumerable<SequenceOf<T>> {
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
	@final func delay(interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { enumerator in
			let disposable = self.enumerate { event in
				switch event {
				case let .Error:
					scheduler.schedule {
						enumerator.put(event)
					}

				default:
					scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) {
						enumerator.put(event)
					}
				}
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Yields all events on the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	@final func deliverOn(scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { enumerator in
			let disposable = self.enumerate { event in
				scheduler.schedule { enumerator.put(event) }
				return ()
			}
			
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Yields `error` after the given interval if the receiver has not yet
	/// completed by that point.
	@final func timeoutWithError(error: NSError, afterInterval interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Enumerable<T> {
		return Enumerable { enumerator in
			let schedulerDisposable = scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) {
				enumerator.put(.Error(error))
			}

			enumerator.disposable.addDisposable(schedulerDisposable)

			let selfDisposable = self.enumerate(enumerator)
			enumerator.disposable.addDisposable(selfDisposable)
		}
	}
}
