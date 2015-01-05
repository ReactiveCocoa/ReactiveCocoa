//
//  ColdSignal.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

private func doNothing<T>(value: T) {}
private func doNothing() {}

/// A stream that will begin generating Events when a sink is attached, possibly
/// performing some side effects in the process. Events are pushed to the sink
/// as they are generated.
///
/// A corollary to this is that different sinks may see a different timing of
/// Events, or even a different version of events altogether.
///
/// Cold signals, once started, do not need to be retained in order to receive
/// events. See the documentation for startWithSink() or start() for more
/// information.
public struct ColdSignal<T> {
	/// The type of value that will be sent to any sink which attaches to this
	/// signal.
	public typealias Element = Event<T>

	/// A closure which implements the behavior for a ColdSignal.
	public typealias Generator = (SinkOf<Element>, CompositeDisposable) -> ()

	/// The file in which this signal was defined, if known.
	internal let file: String?

	/// The function in which this signal was defined, if known.
	internal let function: String?

	/// The line number upon which this signal was defined, if known.
	internal let line: Int?

	private let generator: Generator

	/// Initializes a signal that will run the given action each time the signal
	/// is started.
	public init(_ generator: Generator, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.generator = generator
		self.file = file
		self.line = line
		self.function = function
	}

	internal init(file: String, line: Int, function: String, generator: Generator) {
		self.init(generator, file: file, line: line, function: function)
	}

	/// Runs the given closure with a new disposable, then starts producing
	/// events for the returned sink, performing any side effects embedded
	/// within the ColdSignal.
	///
	/// The disposable given to the closure will cancel the work associated with
	/// event production, and prevent any further events from being sent.
	///
	/// Once the signal has been started, there is no need to maintain a
	/// reference to it. The signal will continue to do work until it sends a
	/// Completed or Error event, or the returned Disposable is explicitly
	/// disposed.
	///
	/// Returns the disposable which was given to the closure.
	public func startWithSink(sinkCreator: Disposable -> SinkOf<Element>) -> Disposable {
		let disposable = CompositeDisposable()
		var innerSink: SinkOf<Element>? = sinkCreator(disposable)

		// Skip all generation work if the disposable was already used.
		if disposable.disposed {
			return disposable
		}

		let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.ColdSignal.startWithSink", DISPATCH_QUEUE_SERIAL)
		disposable.addDisposable {
			// This is redundant with the behavior of the outer sink below for a
			// terminating event, but this ensures that we properly handle
			// simple cancellation as well.
			dispatch_async(queue) {
				innerSink = nil
			}
		}

		let outerSink = SinkOf<Element> { event in
			dispatch_sync(queue) {
				if disposable.disposed {
					return
				}

				if event.isTerminating {
					disposable.dispose()
				}

				// This variable should only be nil after disposal (which occurs
				// upon our current queue), so there's no situation in which
				// this should be nil here.
				innerSink!.put(event)
			}
		}

		generator(outerSink, disposable)
		return disposable
	}

	/// Starts producing events, performing any side effects embedded within the
	/// ColdSignal, and invoking the given handlers for each kind of event
	/// generated.
	///
	/// Once the signal has been started, there is no need to maintain a
	/// reference to it. The signal will continue to do work until it sends a
	/// Completed or Error event, or the returned Disposable is explicitly
	/// disposed.
	///
	/// Returns a disposable that will cancel the work associated with event
	/// production, and prevent any further events from being sent.
	public func start(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> Disposable {
		return startWithSink { _ in Event.sink(next: next, error: error, completed: completed) }
	}
}

/// Convenience constructors.
extension ColdSignal {
	/// Executes the given action whenever the returned signal is started, then
	/// forwards all events from the generated signal.
	public static func lazy(action: () -> ColdSignal) -> ColdSignal {
		return ColdSignal { (sink, disposable) in
			if !disposable.disposed {
				action().startWithSink { innerDisposable in
					disposable.addDisposable(innerDisposable)
					return sink
				}
			}
		}
	}

	/// Creates a signal that will immediately complete.
	public static func empty() -> ColdSignal {
		return ColdSignal { (sink, _) in
			sendCompleted(sink)
		}
	}

	/// Creates a signal that will immediately yield a single value then
	/// complete.
	public static func single(value: T) -> ColdSignal {
		return ColdSignal { (sink, _) in
			sendNext(sink, value)
			sendCompleted(sink)
		}
	}

	/// Creates a signal that will immediately generate an error.
	public static func error(error: NSError) -> ColdSignal {
		return ColdSignal { (sink, _) in
			sendError(sink, error)
		}
	}

	/// Creates a signal that will never send any events.
	public static func never() -> ColdSignal {
		return ColdSignal { _ in () }
	}

	/// Creates a signal that will iterate over the given sequence whenever a
	/// sink is attached.
	///
	/// If the signal will be consumed multiple times, the given sequence must
	/// be multi-pass (i.e., support obtaining and using multiple generators).
	public static func fromValues<S: SequenceType where S.Generator.Element == T>(values: S) -> ColdSignal {
		return ColdSignal { (sink, disposable) in
			var generator = values.generate()

			while let value: T = generator.next() {
				sendNext(sink, value)

				if disposable.disposed {
					return
				}
			}

			sendCompleted(sink)
		}
	}

	/// Creates a signal that will yield events equivalent to the given Result.
	///
	/// Returns a signal that will send one value then complete, or error.
	public static func fromResult(result: Result<T>) -> ColdSignal {
		switch result {
		case let .Success(value):
			return .single(value.unbox)

		case let .Failure(error):
			return .error(error)
		}
	}
}

/// Transformative operators.
extension ColdSignal {
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
	public func mapAccumulate<State, U>(#initialState: State, _ f: (State, T) -> (State?, U)) -> ColdSignal<U> {
		return ColdSignal<U> { (sink, disposable) in
			let state = Atomic(initialState)

			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { value in
					let (maybeState, newValue) = f(state.value, value)
					sendNext(sink, newValue)

					if let s = maybeState {
						state.value = s
					} else {
						sendCompleted(sink)
					}
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					sendCompleted(sink)
				})
			}

			return ()
		}
	}

	/// Maps each value in the stream to a new value.
	public func map<U>(f: T -> U) -> ColdSignal<U> {
		return mapAccumulate(initialState: ()) { (_, value) in
			return ((), f(value))
		}
	}

	/// Preserves only the values of the signal that pass the given predicate.
	public func filter(predicate: T -> Bool) -> ColdSignal {
		return mergeMap { value -> ColdSignal in
			if predicate(value) {
				return .single(value)
			} else {
				return .empty()
			}
		}
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
	public func scan<U>(#initial: U, _ f: (U, T) -> U) -> ColdSignal<U> {
		return mapAccumulate(initialState: initial) { (previous, current) in
			let mapped = f(previous, current)
			return (mapped, mapped)
		}
	}

	/// Combines all of the values in the stream.
	///
	/// Returns a signal which will send the single, aggregated value when
	/// the receiver completes.
	public func reduce<U>(#initial: U, _ f: (U, T) -> U) -> ColdSignal<U> {
		let scanned = scan(initial: initial, f)

		return ColdSignal<U>.single(initial)
			.concat(scanned)
			.takeLast(1)
	}

	/// Combines each value from the signal with its preceding value, starting
	/// with `initialValue`.
	public func combinePrevious(#initial: T) -> ColdSignal<(T, T)> {
		return mapAccumulate(initialState: initial) { (previous, current) in
			return (current, (previous, current))
		}
	}

	/// Returns a signal that will skip the first `count` values from the
	/// receiver, then forward everything afterward.
	public func skip(count: Int) -> ColdSignal {
		precondition(count >= 0)

		if (count == 0) {
			return self
		}

		return self
			.mapAccumulate(initialState: 0) { (n, value) in
				if n >= count {
					return (count, .single(value))
				} else {
					return (n + 1, .empty())
				}
			}
			.merge(identity)
	}

	/// Skips all consecutive, repeating values in the signal, forwarding only
	/// the first occurrence.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            values which are `Equatable`. Simply pass in the `identity`
	///            function.
	public func skipRepeats<U: Equatable>(evidence: ColdSignal -> ColdSignal<U>) -> ColdSignal<U> {
		return evidence(self).skipRepeats { $0 == $1 }
	}

	/// Skips all consecutive, repeating values in the signal, forwarding only
	/// the first occurrence.
	///
	/// isEqual - Used to determine whether two values are equal. The `==`
	///           function will work in most cases.
	public func skipRepeats(isEqual: (T, T) -> Bool) -> ColdSignal<T> {
		return mapAccumulate(initialState: nil) { (maybePrevious: T?, current: T) -> (T??, ColdSignal<T>) in
				if let previous = maybePrevious {
					if isEqual(current, previous) {
						return (current, .empty())
					}
				}

				return (current, .single(current))
			}
			.merge(identity)
	}

	/// Returns a signal that will skip values from the receiver while `pred`
	/// remains `true`, then forward everything afterward.
	public func skipWhile(predicate: T -> Bool) -> ColdSignal {
		return self
			.mapAccumulate(initialState: true) { (skipping, value) in
				if !skipping || !predicate(value) {
					return (false, .single(value))
				} else {
					return (true, .empty())
				}
			}
			.merge(identity)
	}

	/// Returns a signal that will yield the first `count` values from the
	/// receiver.
	public func take(count: Int) -> ColdSignal {
		precondition(count >= 0)

		if count == 0 {
			return .empty()
		}

		return mapAccumulate(initialState: 0) { (n, value) in
			let newN: Int? = (n + 1 < count ? n + 1 : nil)
			return (newN, value)
		}
	}

	/// Waits for the receiver to complete successfully, then forwards only the
	/// last `count` values.
	public func takeLast(count: Int) -> ColdSignal {
		precondition(count >= 0)

		if count == 0 {
			return filter { _ in false }
		}

		return ColdSignal { (sink, disposable) in
			let values: Atomic<[T]> = Atomic([])

			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { value in
					values.modify { (var arr) in
						arr.append(value)
						while arr.count > count {
							arr.removeAtIndex(0)
						}

						return arr
					}

					return ()
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					for v in values.value {
						sendNext(sink, v)
					}

					sendCompleted(sink)
				})
			}
		}
	}

	/// Forwards all events from the receiver, until `trigger` fires, at which
	/// point the returned signal will complete.
	public func takeUntil(trigger: HotSignal<()>) -> ColdSignal {
		let disposable = CompositeDisposable()
		let triggerDisposable = trigger.observe { _ in
			disposable.dispose()
		}

		disposable.addDisposable(triggerDisposable)

		return ColdSignal { (sink, sinkDisposable) in
			// Automatically complete the returned signal when the trigger
			// fires.
			let completingDisposable = ActionDisposable {
				sendCompleted(sink)
			}

			let completingHandle = disposable.addDisposable(completingDisposable)

			self.startWithSink { selfDisposable in
				sinkDisposable.addDisposable {
					selfDisposable.dispose()

					// When the signal terminates, make sure to remove our
					// unique disposable from `disposable`, to avoid infinite
					// memory growth.
					completingHandle.remove()
				}

				return sink
			}
		}
	}

	/// Returns a signal that will yield values from the receiver while
	/// `predicate` remains `true`.
	public func takeWhile(predicate: T -> Bool) -> ColdSignal {
		return self
			.mapAccumulate(initialState: true) { (taking, value) in
				if taking && predicate(value) {
					return (true, .single(value))
				} else {
					return (nil, .empty())
				}
			}
			.merge(identity)
	}

	/// Yields all events on the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func deliverOn(scheduler: Scheduler) -> ColdSignal {
		return ColdSignal { (sink, disposable) in
			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return SinkOf { event in
					scheduler.schedule { sink.put(event) }
					return ()
				}
			}

			return ()
		}
	}

	/// Performs the work of event production on the given Scheduler.
	///
	/// This implies that any side effects embedded in the receiver will be
	/// performed on the given scheduler as well.
	///
	/// Values may still be sent upon other schedulers—this merely affects how
	/// the `start` method is invoked.
	public func evaluateOn(scheduler: Scheduler) -> ColdSignal {
		return ColdSignal { (sink, disposable) in
			let schedulerDisposable = scheduler.schedule {
				self.startWithSink { selfDisposable in
					disposable.addDisposable(selfDisposable)
					return sink
				}

				return ()
			}

			disposable.addDisposable(schedulerDisposable)
		}
	}

	/// Delays `Next` and `Completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// `Error` events are always scheduled immediately.
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> ColdSignal {
		precondition(interval >= 0)

		return ColdSignal { (sink, disposable) in
			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return SinkOf { event in
					switch event {
					case .Error:
						scheduler.schedule {
							sink.put(event)
						}

					default:
						let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
						scheduler.scheduleAfter(date) {
							sink.put(event)
						}
					}
				}
			}

			return ()
		}
	}

	/// Yields `error` after the given interval if the receiver has not yet
	/// completed by that point.
	public func timeoutWithError(error: NSError, afterInterval interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> ColdSignal {
		precondition(interval >= 0)

		return ColdSignal { (sink, disposable) in
			let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
			let timeoutDisposable = scheduler.scheduleAfter(date) {
				sendError(sink, error)
			}

			disposable.addDisposable(timeoutDisposable)

			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)
				return sink
			}

			return ()
		}
	}

	/// Injects side effects to be performed upon the specified signal events.
	public func on(started: () -> () = doNothing, event: Event<T> -> () = doNothing, next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing, terminated: () -> () = doNothing, disposed: () -> () = doNothing) -> ColdSignal {
		return ColdSignal { (sink, disposable) in
			started()
			disposable.addDisposable(disposed)

			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return SinkOf { receivedEvent in
					event(receivedEvent)

					switch receivedEvent {
					case let .Next(value):
						next(value.unbox)

					case let .Error(err):
						error(err)
						terminated()

					case .Completed:
						completed()
						terminated()
					}

					sink.put(receivedEvent)
				}
			}

			return ()
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
		return mergeMap { value in
			switch f(value) {
			case let .Success(box):
				return .single(box.unbox)

			case let .Failure(error):
				return .error(error)
			}
		}
	}

	/// Switches to a new signal when an error occurs.
	public func catch(handler: NSError -> ColdSignal) -> ColdSignal {
		return ColdSignal { (sink, disposable) in
			let serialDisposable = SerialDisposable()
			disposable.addDisposable(serialDisposable)

			self.startWithSink { selfDisposable in
				serialDisposable.innerDisposable = selfDisposable

				return SinkOf<Element> { event in
					switch event {
					case let .Error(error):
						handler(error).startWithSink { handlerDisposable in
							serialDisposable.innerDisposable = handlerDisposable
							return sink
						}

					default:
						sink.put(event)
					}
				}
			}
		}
	}

	/// Brings all signal Events into the monad, allowing them to be manipulated
	/// just like any other value.
	public func materialize() -> ColdSignal<Event<T>> {
		return ColdSignal<Event<T>> { (sink, disposable) in
			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return SinkOf { event in
					sendNext(sink, event)

					if event.isTerminating {
						sendCompleted(sink)
					}
				}
			}

			return ()
		}
	}

	/// The inverse of `materialize`, this will translate a signal of `Event`
	/// _values_ into a signal of those events themselves.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            `Event`s. Simply pass in the `identity` function.
	public func dematerialize<U>(evidence: ColdSignal -> ColdSignal<Event<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { (sink, disposable) in
			evidence(self).startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { event in
					sink.put(event)
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					sendCompleted(sink)
				})
			}

			return ()
		}
	}
}

/// Methods for combining multiple signals.
extension ColdSignal {
	private func startWithStates<U>(disposable: CompositeDisposable, _ selfState: CombineLatestState<T>, _ otherState: CombineLatestState<U>, queue: dispatch_queue_t, onBothNext: () -> (), onError: NSError -> (), onBothCompleted: () -> ()) {
		startWithSink { selfDisposable in
			disposable.addDisposable(selfDisposable)

			return Event.sink(next: { value in
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
	}

	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each.
	public func combineLatestWith<U>(signal: ColdSignal<U>) -> ColdSignal<(T, U)> {
		return ColdSignal<(T, U)> { (sink, disposable) in
			let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.ColdSignal.combineLatestWith", DISPATCH_QUEUE_SERIAL)
			let selfState = CombineLatestState<T>()
			let otherState = CombineLatestState<U>()

			let onBothNext = { () -> () in
				let combined = (selfState.latestValue!, otherState.latestValue!)
				sendNext(sink, combined)
			}

			let onError = { sendError(sink, $0) }
			let onBothCompleted = { sendCompleted(sink) }

			self.startWithStates(disposable, selfState, otherState, queue: queue, onBothNext: onBothNext, onError: onError, onBothCompleted: onBothCompleted)
			signal.startWithStates(disposable, otherState, selfState, queue: queue, onBothNext: onBothNext, onError: onError, onBothCompleted: onBothCompleted)
		}
	}

	/// Zips elements of two signals into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input signals.
	///
	/// The returned signal will complete as soon as one of the signals has
	/// completed, and all pairs up until that point have been sent.
	public func zipWith<U>(signal: ColdSignal<U>) -> ColdSignal<(T, U)> {
		return ColdSignal<(T, U)> { (sink, disposable) in
			let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.ColdSignal.zipWith", DISPATCH_QUEUE_SERIAL)
			let selfState = ZipState<T>()
			let otherState = ZipState<U>()

			let flushEvents: () -> () = {
				while !selfState.values.isEmpty && !otherState.values.isEmpty {
					let pair = (selfState.values[0], otherState.values[0])
					selfState.values.removeAtIndex(0)
					otherState.values.removeAtIndex(0)

					sendNext(sink, pair)
				}

				if (selfState.completed && selfState.values.isEmpty) || (otherState.completed && otherState.values.isEmpty) {
					sendCompleted(sink)
				}
			}

			self.startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { value in
					dispatch_sync(queue) {
						selfState.values.append(value)
						flushEvents()
					}
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					dispatch_sync(queue) {
						selfState.completed = true
						flushEvents()
					}
				})
			}

			signal.startWithSink { signalDisposable in
				disposable.addDisposable(signalDisposable)

				return Event.sink(next: { value in
					dispatch_sync(queue) {
						otherState.values.append(value)
						flushEvents()
					}
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					dispatch_sync(queue) {
						otherState.completed = true
						flushEvents()
					}
				})
			}
		}
	}

	/// Merges a ColdSignal of ColdSignals down into a single ColdSignal, biased toward the
	/// signals added earlier.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward events from the original signals
	/// as they arrive.
	public func merge<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { (sink, disposable) in
			let inFlight = Atomic(1)

			let decrementInFlight: () -> () = {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					sendCompleted(sink)
				}
			}

			evidence(self).startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { signal in
					signal.startWithSink { signalDisposable in
						inFlight.modify { $0 + 1 }

						let signalHandle = disposable.addDisposable(signalDisposable)

						return SinkOf { event in
							if event.isTerminating {
								signalHandle.remove()
							}

							switch event {
							case .Completed:
								decrementInFlight()

							default:
								sink.put(event)
							}
						}
					}

					return ()
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					decrementInFlight()
				})
			}

			return ()
		}
	}

	/// Maps each value that the receiver sends to a new signal, then merges the
	/// resulting signals together.
	///
	/// This is equivalent to map() followed by merge().
	///
	/// Returns a signal that will forward changes from all mapped signals as
	/// they arrive.
	public func mergeMap<U>(f: T -> ColdSignal<U>) -> ColdSignal<U> {
		return map(f).merge(identity)
	}

	/// Switches on a signal of signal, forwarding events from the
	/// latest inner signal.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward events only from the latest
	/// signal sent upon the receiver.
	public func switchToLatest<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { (sink, disposable) in
			let selfCompleted = Atomic(false)
			let latestCompleted = Atomic(false)

			let completeIfNecessary: () -> () = {
				if selfCompleted.value && latestCompleted.value {
					sendCompleted(sink)
				}
			}

			let latestDisposable = SerialDisposable()
			disposable.addDisposable(latestDisposable)

			evidence(self).startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { signal in
					latestDisposable.innerDisposable = nil
					latestCompleted.value = false

					signal.startWithSink { signalDisposable in
						latestDisposable.innerDisposable = signalDisposable

						return SinkOf { innerEvent in
							switch innerEvent {
							case .Completed:
								latestCompleted.value = true
								completeIfNecessary()

							default:
								sink.put(innerEvent)
							}
						}
					}

					return
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					selfCompleted.value = true
					completeIfNecessary()
				})
			}
		}
	}

	/// Maps each value that the receiver sends to a new signal, then forwards
	/// the values sent by the latest mapped signal.
	///
	/// This is equivalent to map() followed by switchToLatest().
	///
	/// Returns a signal that will forward changes only from the latest mapped
	/// signal to arrive.
	public func switchMap<U>(f: T -> ColdSignal<U>) -> ColdSignal<U> {
		return map(f).switchToLatest(identity)
	}

	/// Concatenates each inner signal with the previous and next inner signals.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward events from each of the original
	/// signals, in sequential order.
	public func concat<U>(evidence: ColdSignal -> ColdSignal<ColdSignal<U>>) -> ColdSignal<U> {
		return ColdSignal<U> { (sink, disposable) in
			var state = ConcatState<U>(sink: sink, disposable: disposable)

			evidence(self).startWithSink { selfDisposable in
				disposable.addDisposable(selfDisposable)

				return Event.sink(next: { signal in
					// TODO: Avoid multiple dispatches.
					dispatch_sync(state.queue) {
						state.enqueuedSignals.append(signal)
					}

					state.dequeueIfReady()
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					state.decrementInFlight()
				})
			}
		}
	}

	/// Maps each value that the receiver sends to a new signal, then
	/// concatenates the resulting signals together.
	///
	/// This is equivalent to map() followed by concat().
	///
	/// Returns a signal that will forward changes sequentially from each mapped
	/// signal.
	public func concatMap<U>(f: T -> ColdSignal<U>) -> ColdSignal<U> {
		return map(f).concat(identity)
	}

	/// Concatenates the given signal after the receiver.
	public func concat(signal: ColdSignal) -> ColdSignal {
		return ColdSignal<ColdSignal>.fromValues([ self, signal ])
			.concat(identity)
	}

	/// Ignores all values from the receiver, then starts the given signal,
	/// forwarding its events, once the receiver has completed.
	public func then<U>(signal: ColdSignal<U>) -> ColdSignal<U> {
		return ColdSignal<U> { (sink, disposable) in
			let serialDisposable = SerialDisposable()
			disposable.addDisposable(serialDisposable)

			self.startWithSink { selfDisposable in
				serialDisposable.innerDisposable = selfDisposable

				return Event.sink(error: { error in
					sendError(sink, error)
				}, completed: {
					signal.startWithSink { signalDisposable in
						serialDisposable.innerDisposable = signalDisposable
						return sink
					}

					return ()
				})
			}

			return ()
		}
	}
}

/// An overloaded function that combines the values of up to 10 signals, in the
/// manner described by ColdSignal.combineLatestWith().
public func combineLatest<A, B>(a: ColdSignal<A>, b: ColdSignal<B>) -> ColdSignal<(A, B)> {
	return a.combineLatestWith(b)
}

public func combineLatest<A, B, C>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>) -> ColdSignal<(A, B, C)> {
	return combineLatest(a, b)
		.combineLatestWith(c)
		.map(repack)
}

public func combineLatest<A, B, C, D>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>) -> ColdSignal<(A, B, C, D)> {
	return combineLatest(a, b, c)
		.combineLatestWith(d)
		.map(repack)
}

public func combineLatest<A, B, C, D, E>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>) -> ColdSignal<(A, B, C, D, E)> {
	return combineLatest(a, b, c, d)
		.combineLatestWith(e)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>) -> ColdSignal<(A, B, C, D, E, F)> {
	return combineLatest(a, b, c, d, e)
		.combineLatestWith(f)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>) -> ColdSignal<(A, B, C, D, E, F, G)> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatestWith(g)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G, H>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>, h: ColdSignal<H>) -> ColdSignal<(A, B, C, D, E, F, G, H)> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatestWith(h)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G, H, I>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>, h: ColdSignal<H>, i: ColdSignal<I>) -> ColdSignal<(A, B, C, D, E, F, G, H, I)> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatestWith(i)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G, H, I, J>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>, h: ColdSignal<H>, i: ColdSignal<I>, j: ColdSignal<J>) -> ColdSignal<(A, B, C, D, E, F, G, H, I, J)> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatestWith(j)
		.map(repack)
}

/// An overloaded function that zips the values of up to 10 signals, in the
/// manner described by ColdSignal.zipWith().
public func zip<A, B>(a: ColdSignal<A>, b: ColdSignal<B>) -> ColdSignal<(A, B)> {
	return a.zipWith(b)
}

public func zip<A, B, C>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>) -> ColdSignal<(A, B, C)> {
	return zip(a, b)
		.zipWith(c)
		.map(repack)
}

public func zip<A, B, C, D>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>) -> ColdSignal<(A, B, C, D)> {
	return zip(a, b, c)
		.zipWith(d)
		.map(repack)
}

public func zip<A, B, C, D, E>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>) -> ColdSignal<(A, B, C, D, E)> {
	return zip(a, b, c, d)
		.zipWith(e)
		.map(repack)
}

public func zip<A, B, C, D, E, F>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>) -> ColdSignal<(A, B, C, D, E, F)> {
	return zip(a, b, c, d, e)
		.zipWith(f)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>) -> ColdSignal<(A, B, C, D, E, F, G)> {
	return zip(a, b, c, d, e, f)
		.zipWith(g)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G, H>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>, h: ColdSignal<H>) -> ColdSignal<(A, B, C, D, E, F, G, H)> {
	return zip(a, b, c, d, e, f, g)
		.zipWith(h)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G, H, I>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>, h: ColdSignal<H>, i: ColdSignal<I>) -> ColdSignal<(A, B, C, D, E, F, G, H, I)> {
	return zip(a, b, c, d, e, f, g, h)
		.zipWith(i)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G, H, I, J>(a: ColdSignal<A>, b: ColdSignal<B>, c: ColdSignal<C>, d: ColdSignal<D>, e: ColdSignal<E>, f: ColdSignal<F>, g: ColdSignal<G>, h: ColdSignal<H>, i: ColdSignal<I>, j: ColdSignal<J>) -> ColdSignal<(A, B, C, D, E, F, G, H, I, J)> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zipWith(j)
		.map(repack)
}

/// Blocking methods for receiving values.
extension ColdSignal {
	/// Starts the receiver, then returns the first value received.
	public func first() -> Result<T> {
		let semaphore = dispatch_semaphore_create(0)
		var result: Result<T> = failure(RACError.ExpectedCountMismatch.error)

		take(1).start(next: { value in
			result = success(value)
			dispatch_semaphore_signal(semaphore)
		}, error: { error in
			result = failure(error)
			dispatch_semaphore_signal(semaphore)
		}, completed: {
			dispatch_semaphore_signal(semaphore)
			return ()
		})

		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
		return result
	}

	/// Starts the receiver, then returns the last value received.
	public func last() -> Result<T> {
		return takeLast(1).first()
	}

	/// Starts the receiver, and returns a successful result if exactly one
	/// value is received. If the receiver sends fewer or more values, an error
	/// will be returned instead.
	public func single() -> Result<T> {
		let result = reduce(initial: Array<T>()) { (var array, value) in
			array.append(value)
			return array
		}.first()

		switch result {
		case let .Success(values):
			if values.unbox.count == 1 {
				return success(values.unbox[0])
			} else {
				return failure(RACError.ExpectedCountMismatch.error)
			}

		case let .Failure(error):
			return failure(error)
		}
	}

	/// Starts the receiver, then waits for completion.
	public func wait() -> Result<()> {
		return reduce(initial: ()) { (_, _) in () }
			.takeLast(1)
			.first()
	}
}

/// Conversions from ColdSignal to HotSignal.
extension ColdSignal {
	/// Immediately starts the receiver, then forwards all values on the
	/// returned signal.
	///
	/// If `errorHandler` is `nil`, the stream MUST NOT produce an `Error`
	/// event, or the program will terminate.
	public func startMulticasted(#errorHandler: (NSError -> ())?, completionHandler: () -> () = doNothing) -> HotSignal<T> {
		return HotSignal { sink in
			var onError = { (error: NSError) in
				fatalError("Unhandled error in startMulticasted: \(error)")
			}

			// Apparently ?? has trouble with closures, so use this lame pattern
			// instead.
			if let errorHandler = errorHandler {
				onError = errorHandler
			}

			self.start(next: { value in
				sink.put(value)
			}, error: onError, completed: completionHandler)

			return
		}
	}
}

/// Debugging utilities.
extension ColdSignal {
	private func logEvents(predicate: Event<T> -> Bool) -> ColdSignal {
		return on(event: { event in
			if predicate(event) {
				debugPrintln("\(self.debugDescription): \(event)")
			}
		})
	}

	/// Logs every event that passes through the signal.
	public func log() -> ColdSignal {
		return logEvents { _ in true }
	}

	/// Logs every `next` event that passes through the signal.
	public func logNext() -> ColdSignal {
		return logEvents { event in
			switch event {
			case .Next:
				return true

			default:
				return false
			}
		}
	}

	/// Logs every `error` event that passes through the signal.
	public func logError() -> ColdSignal {
		return logEvents { event in
			switch event {
			case .Error:
				return true

			default:
				return false
			}
		}
	}

	/// Logs every `completed` event that passes through the signal.
	public func logCompleted() -> ColdSignal {
		return logEvents { event in
			switch event {
			case .Completed:
				return true

			default:
				return false
			}
		}
	}
}

extension ColdSignal: DebugPrintable {
	public var debugDescription: String {
		let function = self.function ?? ""
		let file = self.file ?? ""
		let line = self.line?.description ?? ""

		return "\(function).ColdSignal (\(file):\(line))"
	}
}

/// Represents a stream event.
///
/// Streams must conform to the grammar:
/// `Next* (Error | Completed)?`
public enum Event<T> {
	/// A value provided by the stream.
	case Next(Box<T>)

	/// The stream terminated because of an error.
	case Error(NSError)

	/// The stream successfully terminated.
	case Completed

	/// Whether this event indicates stream termination (from success or
	/// failure).
	public var isTerminating: Bool {
		switch self {
		case let .Next:
			return false

		default:
			return true
		}
	}

	/// The value in this event, if it was a `Next`.
	public var value: T? {
		switch self {
		case let .Next(value):
			return value.unbox

		default:
			return nil
		}
	}

	/// The error in this event, if it was an `Error`.
	public var error: NSError? {
		switch self {
		case let .Error(error):
			return error

		default:
			return nil
		}
	}

	/// Lifts the given function over the event's value.
	public func map<U>(f: T -> U) -> Event<U> {
		switch self {
		case let .Next(box):
			return .Next(Box(f(box.unbox)))

		case let .Error(error):
			return .Error(error)

		case let .Completed:
			return .Completed
		}
	}

	/// Case analysis on the receiver.
	public func event<U>(#ifNext: T -> U, ifError: NSError -> U, ifCompleted: @autoclosure () -> U) -> U {
		switch self {
		case let .Next(box):
			return ifNext(box.unbox)

		case let .Error(err):
			return ifError(err)

		case let .Completed:
			return ifCompleted()
		}
	}

	/// Creates a sink that can receive events of this type, then invoke the
	/// given handlers based on the kind of event received.
	public static func sink(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> SinkOf<Event> {
		return SinkOf { event in
			switch event {
			case let .Next(value):
				next(value.unbox)

			case let .Error(err):
				error(err)

			case .Completed:
				completed()
			}
		}
	}
}

public func == <T: Equatable> (lhs: Event<T>, rhs: Event<T>) -> Bool {
	switch (lhs, rhs) {
	case let (.Next(left), .Next(right)):
		return left.unbox == right.unbox

	case let (.Error(left), .Error(right)):
		return left == right

	case (.Completed, .Completed):
		return true

	default:
		return false
	}
}

extension Event: Printable {
	public var description: String {
		switch self {
		case let .Next(value):
			return "NEXT \(value.unbox)"

		case let .Error(error):
			return "ERROR \(error)"

		case .Completed:
			return "COMPLETED"
		}
	}
}

/// Puts a `Next` event into the given sink.
public func sendNext<T>(sink: SinkOf<Event<T>>, value: T) {
	sink.put(.Next(Box(value)))
}

/// Puts an `Error` event into the given sink.
public func sendError<T>(sink: SinkOf<Event<T>>, error: NSError) {
	sink.put(Event<T>.Error(error))
}

/// Puts a `Completed` event into the given sink.
public func sendCompleted<T>(sink: SinkOf<Event<T>>) {
	sink.put(Event<T>.Completed)
}

private class CombineLatestState<T> {
	var latestValue: T?
	var completed = false
}

private class ZipState<T> {
	var values: [T] = []
	var completed = false
}

private class ConcatState<T> {
	let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.ColdSignal.concat", DISPATCH_QUEUE_SERIAL)
	let sink: SinkOf<Event<T>>
	let disposable: CompositeDisposable

	var inFlight: Int = 1
	var enqueuedSignals = [ColdSignal<T>]()
	var currentSignal: ColdSignal<T>?

	init(sink: SinkOf<Event<T>>, disposable: CompositeDisposable) {
		self.sink = sink
		self.disposable = disposable
	}

	func decrementInFlight() {
		dispatch_sync(queue) {
			if --self.inFlight == 0 && self.enqueuedSignals.count == 0 && self.currentSignal == nil {
				sendCompleted(self.sink)
			}
		}
	}

	func dequeueIfReady() {
		var signal: ColdSignal<T>?

		dispatch_sync(queue) {
			if self.currentSignal != nil {
				return
			} else if self.enqueuedSignals.count == 0 {
				return
			}

			signal = self.enqueuedSignals.removeAtIndex(0)
			self.currentSignal = signal
			self.inFlight++
		}

		if let signal = signal {
			signal.startWithSink { signalDisposable in
				self.disposable.addDisposable(signalDisposable)

				return Event.sink(next: { value in
					sendNext(self.sink, value)
				}, error: { error in
					sendError(self.sink, error)

					// TODO: We should remove our disposable from the
					// composite disposable here, but that is non-trivial to
					// do right now. See https://github.com/ReactiveCocoa/ReactiveCocoa/issues/1535.
				}, completed: {
					dispatch_sync(self.queue) {
						self.currentSignal = nil
					}

					// TODO: Avoid multiple dispatches.
					self.decrementInFlight()
					self.dequeueIfReady()
				})
			}
		}
	}
}
