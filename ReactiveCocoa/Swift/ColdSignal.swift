//
//  ColdSignal.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

func doNothing<T>(value: T) {}
func doNothing(error: NSError) {}
func doNothing() {}

/// A stream that will begin generating Events when a Subscriber is attached,
/// possibly performing some side effects in the process. Events are pushed to
/// the subscriber as they are generated.
///
/// A corollary to this is that different Subscribers may see a different timing
/// of Events, or even a different version of events altogether.
public struct ColdSignal<T> {
	private let generator: Subscriber<T> -> ()

	/// Initializes a signal that will run the given action whenever a
	/// subscription is created.
	public init(generator: Subscriber<T> -> ()) {
		self.generator = generator
	}

	/// Creates a signal that will execute the given action upon subscription,
	/// then forward all events from the generated signal.
	public static func defer(action: () -> ColdSignal) -> ColdSignal {
		return ColdSignal { subscriber in
			action().subscribe(subscriber)
			return ()
		}
	}

	/// Creates a signal that will immediately complete.
	public static func empty() -> ColdSignal {
		return ColdSignal { subscriber in
			subscriber.put(.Completed)
		}
	}

	/// Creates a signal that will immediately yield a single value then
	/// complete.
	public static func single(value: T) -> ColdSignal {
		return ColdSignal { subscriber in
			subscriber.put(.Next(Box(value)))
			subscriber.put(.Completed)
		}
	}

	/// Creates a signal that will immediately generate an error.
	public static func error(error: NSError) -> ColdSignal {
		return ColdSignal { subscriber in
			subscriber.put(.Error(error))
		}
	}

	/// Creates a signal that will iterate over the given sequence whenever a
	/// Subscriber is attached.
	///
	/// If the signal will be consumed multiple times, the given sequence must
	/// be multi-pass (i.e., support obtaining and using multiple generators).
	public static func fromValues<S: SequenceType where S.Generator.Element == T>(values: S) -> ColdSignal {
		return ColdSignal { subscriber in
			var generator = values.generate()

			while let value: T = generator.next() {
				subscriber.put(.Next(Box(value)))
			}

			subscriber.put(.Completed)
		}
	}

	/// Creates a signal that will never send any events.
	public static func never() -> ColdSignal {
		return ColdSignal { _ in () }
	}

	/// Starts producing events for the given subscriber, performing any side
	/// effects embedded within the ColdSignal.
	///
	/// Returns a Disposable which will cancel the work associated with event
	/// production, and prevent any further events from being sent.
	public func subscribe(subscriber: Subscriber<T>) -> Disposable {
		// TODO: We need an intermediate subscriber here, so disposal doesn't
		// cancel everything about this given subscriber.
		generator(subscriber)
		return subscriber.disposable
	}

	/// Convenience function to invoke subscribe() with a Subscriber that has
	/// the given callbacks for each event type.
	public func subscribe(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable {
		return subscribe(Subscriber(next: next, error: error, completed: completed))
	}

	/// Maps over the elements of the signal, accumulating a state along the
	/// way.
	///
	/// This is meant as a primitive operator from which more complex operators
	/// can be built.
	///
	/// Yielding a `nil` state at any point will stop evaluation of the original
	/// signal, and dispose of it.
	///
	/// Returns a signal of the mapped values.
	public func mapAccumulate<State, U>(initialState: State, _ f: (State, T) -> (State?, U)) -> ColdSignal<U> {
		return ColdSignal<U> { subscriber in
			let state = Atomic(initialState)
			let disposable = self.subscribe(next: { value in
				let (maybeState, newValue) = f(state.value, value)
				subscriber.put(.Next(Box(newValue)))

				if let s = maybeState {
					state.value = s
				} else {
					subscriber.put(.Completed)
				}
			}, error: { error in
				subscriber.put(.Error(error))
			}, completed: {
				subscriber.put(.Completed)
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Merges a signal of signals down into a single signal, biased toward the
	/// signals added earlier.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward events from the original signals
	/// as they arrive.
	public func merge<U>(evidence: ColdSignal<T> -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { subscriber in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)

			let decrementInFlight: () -> () = {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					subscriber.put(.Completed)
				}
			}

			let selfDisposable = evidence(self).subscribe(next: { stream in
				inFlight.modify { $0 + 1 }

				let streamDisposable = SerialDisposable()
				disposable.addDisposable(streamDisposable)

				streamDisposable.innerDisposable = stream.subscribe(Subscriber { event in
					if event.isTerminating {
						streamDisposable.dispose()
						disposable.pruneDisposed()
					}

					switch event {
					case let .Completed:
						decrementInFlight()

					default:
						subscriber.put(event)
					}
				})
			}, error: { error in
				subscriber.put(.Error(error))
			}, completed: {
				decrementInFlight()
			})

			subscriber.disposable.addDisposable(selfDisposable)
		}
	}

	/// Switches on a signal of signal, forwarding events from the
	/// latest inner signal.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward events only from the latest
	/// signal sent upon the receiver.
	public func switchToLatest<U>(evidence: ColdSignal<T> -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { subscriber in
			let selfCompleted = Atomic(false)
			let latestCompleted = Atomic(false)

			let completeIfNecessary: () -> () = {
				if selfCompleted.value && latestCompleted.value {
					subscriber.put(.Completed)
				}
			}

			let latestDisposable = SerialDisposable()
			subscriber.disposable.addDisposable(latestDisposable)

			let selfDisposable = evidence(self).subscribe(next: { stream in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = stream.subscribe(Subscriber { innerEvent in
					switch innerEvent {
					case let .Completed:
						latestCompleted.value = true
						completeIfNecessary()

					default:
						subscriber.put(innerEvent)
					}
				})
			}, error: { error in
				subscriber.put(.Error(error))
			}, completed: {
				selfCompleted.value = true
				completeIfNecessary()
			})

			subscriber.disposable.addDisposable(selfDisposable)
		}
	}

	/// Maps each value in the stream to a new value.
	public func map<U>(f: T -> U) -> ColdSignal<U> {
		return mapAccumulate(()) { (_, value) in
			return ((), f(value))
		}
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
	public func scan<U>(initialValue: U, _ f: (U, T) -> U) -> ColdSignal<U> {
		return mapAccumulate(initialValue) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	/// Returns a signal that will yield the first `count` values from the
	/// receiver.
	public func take(count: Int) -> ColdSignal {
		if count == 0 {
			return .empty()
		}

		return mapAccumulate(0) { (n, value) in
			let newN: Int? = (n + 1 < count ? n + 1 : nil)
			return (newN, value)
		}
	}

	/// Returns a signal that will yield values from the receiver while
	/// `predicate` remains `true`.
	public func takeWhile(predicate: T -> Bool) -> ColdSignal {
		return self
			.mapAccumulate(true) { (taking, value) in
				if taking && predicate(value) {
					return (true, .single(value))
				} else {
					return (nil, .empty())
				}
			}
			.merge(identity)
	}

	/// Combines each value from the signal with its preceding value, starting
	/// with `initialValue`.
	public func combinePrevious(initialValue: T) -> ColdSignal<(T, T)> {
		return mapAccumulate(initialValue) { (previous, current) in
			return (current, (previous, current))
		}
	}

	/// Returns a signal that will skip the first `count` values from the
	/// receiver, then forward everything afterward.
	public func skip(count: Int) -> ColdSignal {
		if (count == 0) {
			return self
		}

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

	/// Returns a signal that will skip values from the receiver while `pred`
	/// remains `true`, then forward everything afterward.
	public func skipWhile(pred: T -> Bool) -> ColdSignal {
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

	/// Preserves only the values of the signal that pass the given predicate.
	public func filter(pred: T -> Bool) -> ColdSignal {
		return self
			.map { value -> ColdSignal<T> in
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
	public func skipRepeats<U: Equatable>(evidence: ColdSignal -> ColdSignal<U>) -> ColdSignal<U> {
		return evidence(self)
			.mapAccumulate(nil) { (maybePrevious: U?, current: U) -> (U??, ColdSignal<U>) in
				if let previous = maybePrevious {
					if current == previous {
						return (current, .empty())
					}
				}

				return (current, .single(current))
			}
			.merge(identity)
	}

	/// Brings all signal Events into the monad, allowing them to be manipulated
	/// just like any other value.
	public func materialize() -> ColdSignal<Event<T>> {
		return ColdSignal<Event<T>> { subscriber in
			let disposable = self.subscribe(Subscriber { event in
				subscriber.put(.Next(Box(event)))

				if event.isTerminating {
					subscriber.put(.Completed)
				}
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// The inverse of `materialize`, this will translate a signal of `Event`
	/// _values_ into a signal of those events themselves.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            `Event`s. Simply pass in the `identity` function.
	public func dematerialize<U>(evidence: ColdSignal -> ColdSignal<Event<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { subscriber in
			let disposable = evidence(self).subscribe(next: subscriber.put, error: { error in
				subscriber.put(.Error(error))
			}, completed: {
				subscriber.put(.Completed)
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Switches to a new signal when an error occurs.
	public func catch(handler: NSError -> ColdSignal) -> ColdSignal {
		return ColdSignal { subscriber in
			let serialDisposable = SerialDisposable()
			subscriber.disposable.addDisposable(serialDisposable)

			serialDisposable.innerDisposable = self.subscribe(Subscriber { event in
				switch event {
				case let .Error(error):
					let newStream = handler(error)
					serialDisposable.innerDisposable = newStream.subscribe(subscriber)

				default:
					subscriber.put(event)
				}
			})
		}
	}

	/// Injects side effects to be performed upon the specified signal events.
	func on(subscribe: () -> () = doNothing, next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing, terminated: () -> () = doNothing, disposed: () -> () = doNothing) -> ColdSignal {
		return ColdSignal { subscriber in
			subscriber.disposable.addDisposable(ActionDisposable(disposed))

			let disposable = self.subscribe(next: { value in
				next(value)
			}, error: { err in
				error(err)
				terminated()
			}, completed: {
				completed()
				terminated()
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Performs the work of event production on the given Scheduler.
	///
	/// This implies that any side effects embedded in the receiver will be
	/// performed on the given scheduler as well.
	///
	/// Values may still be sent upon other schedulers—this merely affects how
	/// the `subscribe` method is invoked.
	public func subscribeOn(scheduler: Scheduler) -> ColdSignal {
		return ColdSignal { subscriber in
			let disposable = self.subscribe(Subscriber { event in
				scheduler.schedule { subscriber.put(event) }
				return ()
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Concatenates `signal` after the receiver.
	public func concat(signal: ColdSignal) -> ColdSignal {
		return ColdSignal { subscriber in
			let serialDisposable = SerialDisposable()
			subscriber.disposable.addDisposable(serialDisposable)

			serialDisposable.innerDisposable = self.subscribe(Subscriber { event in
				switch event {
				case let .Completed:
					serialDisposable.innerDisposable = signal.subscribe(subscriber)

				default:
					subscriber.put(event)
				}
			})
		}
	}

	/// Waits for the receiver to complete successfully, then forwards only the
	/// last `count` values.
	public func takeLast(count: Int) -> ColdSignal {
		return ColdSignal { subscriber in
			let values: Atomic<[T]> = Atomic([])
			let disposable = self.subscribe(next: { value in
				values.modify { (var arr) in
					arr.append(value)
					while arr.count > count {
						arr.removeAtIndex(0)
					}

					return arr
				}

				return ()
			}, error: { error in
				subscriber.put(.Error(error))
			}, completed: {
				for v in values.value {
					subscriber.put(.Next(Box(v)))
				}

				subscriber.put(.Completed)
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Combines all of the values in the stream.
	///
	/// Returns a signal which will send the single, aggregated value when
	/// the receiver completes.
	public func reduce<U>(#initial: U, _ f: (U, T) -> U) -> ColdSignal<U> {
		let scanned = scan(initial, f)

		return ColdSignal<U>.single(initial)
			.concat(scanned)
			.takeLast(1)
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Error` events are always scheduled immediately.
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> ColdSignal {
		return ColdSignal { subscriber in
			let disposable = self.subscribe(Subscriber { event in
				switch event {
				case let .Error:
					scheduler.schedule {
						subscriber.put(event)
					}

				default:
					let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
					scheduler.scheduleAfter(date) {
						subscriber.put(event)
					}
				}
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Yields all events on the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func deliverOn(scheduler: Scheduler) -> ColdSignal {
		return ColdSignal { subscriber in
			let disposable = self.subscribe(Subscriber { event in
				scheduler.schedule { subscriber.put(event) }
				return ()
			})

			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Yields `error` after the given interval if the receiver has not yet
	/// completed by that point.
	public func timeoutWithError(error: NSError, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> ColdSignal {
		return ColdSignal { subscriber in
			let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
			let schedulerDisposable = scheduler.scheduleAfter(date) {
				subscriber.put(.Error(error))
			}

			subscriber.disposable.addDisposable(schedulerDisposable)

			let selfDisposable = self.subscribe(subscriber)
			subscriber.disposable.addDisposable(selfDisposable)
		}
	}

	/// Performs the given action upon each value in the receiver, bailing out
	/// with an error if it returns `false`.
	public func try(f: (T, NSErrorPointer) -> Bool) -> ColdSignal {
		return tryMap { (value, error) in f(value, error) ? value : nil }
	}

	/// Attempts to map each value in the receiver, bailing out with an error if
	/// a given mapping is `nil`.
	public func tryMap<U>(f: (T, NSErrorPointer) -> U?) -> ColdSignal<U> {
		return tryMap { value -> Result<U> in
			var error: NSError?
			let maybeValue = f(value, &error)

			if let v = maybeValue {
				return .Success(Box(v))
			} else {
				return .Failure(error.orDefault(RACError.Empty.error))
			}
		}
	}

	/// Attempts to map each value in the receiver, bailing out with an error if
	/// a given mapping fails.
	public func tryMap<U>(f: T -> Result<U>) -> ColdSignal<U> {
		return self
			.map { value in
				switch f(value) {
				case let .Success(box):
					return .single(box.unbox)

				case let .Failure(error):
					return .error(error)
				}
			}
			.merge(identity)
	}

	/// Ignores all values from the receiver, then subscribes to and forwards
	/// events from the given signal once the receiver has completed.
	public func then<U>(signal: ColdSignal<U>) -> ColdSignal<U> {
		return ColdSignal<U> { subscriber in
			let disposable = SerialDisposable()
			subscriber.disposable.addDisposable(disposable)

			disposable.innerDisposable = self.subscribe(error: { error in
				subscriber.put(.Error(error))
			}, completed: {
				disposable.innerDisposable = signal.subscribe(subscriber)
			})
		}
	}

	private func subscribeWithStates<U>(selfState: CombineLatestState<T>, _ otherState: CombineLatestState<U>, queue: dispatch_queue_t, onBothNext: () -> (), onError: NSError -> (), onBothCompleted: () -> ()) -> Disposable {
		return subscribe(next: { value in
			dispatch_sync(queue) {
				selfState.latestValue = value
				if otherState.latestValue == nil {
					return
				}

				onBothNext()
			}
		}, error: onError, completed: {
			dispatch_sync(queue) {
				selfState.completed = true
				if otherState.completed {
					onBothCompleted()
				}
			}
		})
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each.
	public func combineLatestWith<U>(signal: ColdSignal<U>) -> ColdSignal<(T, U)> {
		return ColdSignal<(T, U)> { subscriber in
			let queue = dispatch_queue_create("com.github.ReactiveCocoa.ColdSignal.combineLatestWith", DISPATCH_QUEUE_SERIAL)
			let selfState = CombineLatestState<T>()
			let otherState = CombineLatestState<U>()

			let onBothNext = { () -> () in
				let combined = (selfState.latestValue!, otherState.latestValue!)
				subscriber.put(.Next(Box(combined)))
			}

			let onError = { subscriber.put(.Error($0)) }
			let onBothCompleted = { subscriber.put(.Completed) }

			subscriber.disposable.addDisposable(self.subscribeWithStates(selfState, otherState, queue: queue, onBothNext: onBothNext, onError: onError, onBothCompleted: onBothCompleted))
			subscriber.disposable.addDisposable(signal.subscribeWithStates(otherState, selfState, queue: queue, onBothNext: onBothNext, onError: onError, onBothCompleted: onBothCompleted))
		}
	}

	/// Immediately subscribes to the receiver, then forwards all values on the
	/// returned signal.
	///
	/// If `errorHandler` is `nil`, the stream must never produce an `Error`
	/// event.
	public func start(errorHandler: (NSError -> ())?, completionHandler: () -> () = doNothing) -> HotSignal<T> {
		let (signal, sink) = HotSignal<T>.pipe()

		var onError = { (error: NSError) in
			assert(false)
		}

		// Apparently ?? has trouble with closures, so use this lame pattern
		// instead.
		if let errorHandler = errorHandler {
			onError = errorHandler
		}

		subscribe(next: { value in
			sink.put(value)
		}, error: onError, completed: completionHandler)

		return signal
	}
}

/// Receives Events from a ColdSignal.
public final class Subscriber<T>: SinkType {
	public typealias Element = Event<T>

	private let sink: Atomic<SinkOf<Element>?>

	/// A list of Disposables to dispose of when the subscriber receives
	/// a terminating event, or if the subscription is canceled.
	public let disposable = CompositeDisposable()

	/// Initializes a Subscriber that will forward events to the given sink.
	public init<S: SinkType where S.Element == Event<T>>(_ sink: S) {
		self.sink = Atomic(SinkOf(sink))

		// This is redundant with the behavior of put() in case of
		// a terminating event, but ensures that we get rid of the closure
		// upon cancellation as well.
		disposable.addDisposable {
			self.sink.value = nil
		}
	}

	/// Initializes a Subscriber that will perform the given action whenever an
	/// event is received.
	public convenience init(handler: Event<T> -> ()) {
		self.init(SinkOf(handler))
	}

	/// Initializes a Subscriber with different callbacks to invoke, based
	/// on the type of Event received.
	public convenience init(next: T -> (), error: NSError -> (), completed: () -> ()) {
		self.init(SinkOf<Event<T>> { event in
			switch event {
			case let .Next(box):
				next(box.unbox)

			case let .Error(err):
				error(err)

			case let .Completed:
				completed()
			}
		})
	}

	public func put(event: Event<T>) {
		let oldSink = sink.modify { s in
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

private class CombineLatestState<T> {
	var latestValue: T?
	var completed = false
}
