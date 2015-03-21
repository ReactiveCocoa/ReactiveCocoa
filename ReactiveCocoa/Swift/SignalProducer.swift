import LlamaKit

/// A SignalProducer creates Signals that can produce values of type `T` and/or
/// error out with errors of type `E`. If no errors should be possible, NoError
/// can be specified for `E`.
///
/// SignalProducers can be used to represent operations or tasks, like network
/// requests, where each invocation of start() will create a new underlying
/// operation. This ensures that consumers will receive the results, versus a
/// plain Signal, where the results might be sent before any observers are
/// attached.
///
/// Because of the behavior of start(), different Signals created from the
/// producer may see a different version of Events. The Events may arrive in a
/// different order between Signals, or the stream might be completely
/// different!
public struct SignalProducer<T, E: ErrorType> {
	private let startHandler: (Signal<T, E>.Observer, CompositeDisposable) -> ()

	/// Initializes a SignalProducer that will invoke the given closure once
	/// for each invocation of start().
	///
	/// The events that the closure puts into the given sink will become the
	/// events sent by the started Signal to its observers.
	///
	/// If the Disposable returned from start() is disposed or a terminating
	/// event is sent to the observer, the given CompositeDisposable will be
	/// disposed, at which point work should be interrupted and any temporary
	/// resources cleaned up.
	public init(_ startHandler: (Signal<T, E>.Observer, CompositeDisposable) -> ()) {
		self.startHandler = startHandler
	}

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete.
	public init(value: T) {
		self.init({ observer, disposable in
			sendNext(observer, value)
			sendCompleted(observer)
		})
	}

	/// Creates a producer for a Signal that will immediately send an error.
	public init(error: E) {
		self.init({ observer, disposable in
			sendError(observer, error)
		})
	}

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete, or immediately send an error, depending on the given
	/// Result.
	public init(result: Result<T, E>) {
		switch result {
		case let .Success(value):
			self.init(value: value.unbox)

		case let .Failure(error):
			self.init(error: error.unbox)
		}
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	public init<S: SequenceType where S.Generator.Element == T>(values: S) {
		self.init({ observer, disposable in
			var generator = values.generate()

			while let value: T = generator.next() {
				sendNext(observer, value)

				if disposable.disposed {
					break
				}
			}

			sendCompleted(observer)
		})
	}

	/// A producer for a Signal that will immediately complete without sending
	/// any values.
	public static var empty: SignalProducer {
		return self { observer, disposable in
			sendCompleted(observer)
		}
	}

	/// A producer for a Signal that never sends any events to its observers.
	public static var never: SignalProducer {
		return self { _ in () }
	}

	/// Creates a buffer for Events, with the given capacity, and a
	/// SignalProducer for a signal that will send Events from the buffer.
	///
	/// When events are put into the returned observer (sink), they will be
	/// added to the buffer. If the buffer is already at capacity, the earliest
	/// (oldest) event will be dropped to make room for the new event.
	///
	/// Signals created from the returned producer will stay alive until a
	/// terminating event is added to the buffer. If the buffer does not contain
	/// such an event when the Signal is started, all events sent to the
	/// returned observer will be automatically forwarded to the Signal’s
	/// observers until a terminating event is received.
	///
	/// After a terminating event has been added to the buffer, the observer
	/// will not add any further events.
	public static func buffer(_ capacity: Int = Int.max) -> (SignalProducer, Signal<T, E>.Observer) {
		precondition(capacity >= 0)

		let lock = NSRecursiveLock()
		lock.name = "org.reactivecocoa.ReactiveCocoa.SignalProducer.buffer"

		var events: [Event<T, E>] = []
		var observers: Bag<Signal<T, E>.Observer>? = Bag()

		let producer = self { observer, disposable in
			lock.lock()
			for event in events {
				observer.put(event)
			}

			let token = observers?.insert(observer)
			lock.unlock()

			if let token = token {
				disposable.addDisposable {
					lock.lock()
					observers?.removeValueForToken(token)
					lock.unlock()
				}
			}
		}

		let observer = Signal<T, E>.Observer { event in
			lock.lock()

			// If not disposed…
			if let liveObservers = observers {
				if event.isTerminating {
					observers = nil
				}

				events.append(event)
				while events.count > capacity {
					events.removeAtIndex(0)
				}

				for observer in liveObservers {
					observer.put(event)
				}
			}

			lock.unlock()
		}

		return (producer, observer)
	}

	/// Creates a SignalProducer that will attempt the given operation once for
	/// each invocation of start().
	///
	/// Upon success, the started signal will send the resulting value then
	/// complete. Upon failure, the started signal will send the error that
	/// occurred.
	public static func try(operation: () -> Result<T, E>) -> SignalProducer {
		return self { observer, disposable in
			switch operation() {
			case let .Success(value):
				sendNext(observer, value.unbox)
				sendCompleted(observer)

			case let .Failure(error):
				sendError(observer, error.unbox)
			}
		}
	}

	/// Creates a Signal from the producer, passes it into the given closure,
	/// then starts sending events on the Signal when the closure has returned.
	///
	/// The closure will also receive a disposable which can be used to
	/// interrupt the work associated with the signal and immediately send an
	/// `Interrupted` event.
	public func startWithSignal(setUp: (Signal<T, E>, Disposable) -> ()) {
		let (signal, observer) = Signal<T, E>.pipe()

		// Create a composite disposable that will automatically be torn
		// down when the signal terminates.
		let compositeDisposable = CompositeDisposable()
		compositeDisposable.addDisposable {
			// Upon early disposable, interrupt the observer and all dependents.
			sendInterrupted(observer)
		}

		setUp(signal, compositeDisposable)

		if !compositeDisposable.disposed {
			let wrapperObserver = Signal<T, E>.Observer { event in
				observer.put(event)

				if event.isTerminating {
					// Dispose only after notifying the Signal, so disposal
					// logic is consistently the last thing to run.
					compositeDisposable.dispose()
				}
			}

			startHandler(wrapperObserver, compositeDisposable)
		}
	}

	/// Creates a Signal from the producer, then attaches the given sink to the
	/// Signal as an observer.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the signal and immediately send an `Interrupted` event.
	public func start<S: SinkType where S.Element == Event<T, E>>(sink: S) -> Disposable {
		var disposable: Disposable!

		startWithSignal { signal, innerDisposable in
			signal.observe(sink)
			disposable = innerDisposable
		}

		return disposable
	}

	/// Creates a Signal from the producer, then adds exactly one observer to
	/// the Signal, which will invoke the given callbacks when events are
	/// received.
	///
	/// Returns a Disposable which can be used to interrupt the work associated
	/// with the Signal, and prevent any future callbacks from being invoked.
	public func start(next: (T -> ())? = nil, error: (E -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil) -> Disposable {
		return start(Event.sink(next: next, error: error, completed: completed, interrupted: interrupted))
	}

	/// Lifts an unary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new SignalProducer which will apply
	/// the given Signal operator to _every_ created Signal, just as if the
	/// operator had been applied to each Signal yielded from start().
	public func lift<U, F>(transform: Signal<T, E> -> Signal<U, F>) -> SignalProducer<U, F> {
		return SignalProducer<U, F> { observer, outerDisposable in
			self.startWithSignal { signal, innerDisposable in
				outerDisposable.addDisposable(innerDisposable)

				transform(signal).observe(observer)
			}
		}
	}

	/// Lifts a binary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new SignalProducer which will apply
	/// the given Signal operator to _every_ Signal created from the two
	/// producers, just as if the operator had been applied to each Signal
	/// yielded from start().
	public func lift<U, F, V, G>(transform: Signal<U, F> -> Signal<T, E> -> Signal<V, G>) -> SignalProducer<U, F> -> SignalProducer<V, G> {
		return { otherProducer in
			return SignalProducer<V, G> { observer, outerDisposable in
				self.startWithSignal { signal, disposable in
					outerDisposable.addDisposable(disposable)

					otherProducer.startWithSignal { otherSignal, otherDisposable in
						outerDisposable.addDisposable(otherDisposable)

						transform(otherSignal)(signal).observe(observer)
					}
				}
			}
		}
	}
}

/// Applies a Signal operator to a SignalProducer (equivalent to
/// SignalProducer.lift).
///
/// This will create a new SignalProducer which will apply the given Signal
/// operator to _every_ created Signal, just as if the operator had been applied
/// to each Signal yielded from start().
///
/// Example:
///
/// 	let filteredProducer = intProducer |> filter { num in num % 2 == 0 }
public func |> <T, E, U, F>(producer: SignalProducer<T, E>, transform: Signal<T, E> -> Signal<U, F>) -> SignalProducer<U, F> {
	return producer.lift(transform)
}

/// Applies a SignalProducer operator to a SignalProducer.
///
/// Example:
///
/// 	filteredProducer
/// 	|> startOn(MainScheduler())
/// 	|> start { signal in
/// 		signal.observe(next: { num in println(num) })
/// 	}
public func |> <T, E, X>(producer: SignalProducer<T, E>, transform: SignalProducer<T, E> -> X) -> X {
	return transform(producer)
}

/// Creates a repeating timer of the given interval, with a reasonable
/// default leeway, sending updates on the given scheduler.
///
/// This timer will never complete naturally, so all invocations of start() must
/// be disposed to avoid leaks.
public func timer(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<NSDate, NoError> {
	// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
	// at least 10% of the timer interval.
	return timer(interval, onScheduler: scheduler, withLeeway: interval * 0.1)
}

/// Creates a repeating timer of the given interval, sending updates on the
/// given scheduler.
///
/// This timer will never complete naturally, so all invocations of start() must
/// be disposed to avoid leaks.
public func timer(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType, withLeeway leeway: NSTimeInterval) -> SignalProducer<NSDate, NoError> {
	precondition(interval >= 0)
	precondition(leeway >= 0)

	return SignalProducer { observer, compositeDisposable in
		let disposable = scheduler.scheduleAfter(scheduler.currentDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
			sendNext(observer, scheduler.currentDate)
		}

		compositeDisposable.addDisposable(disposable)
	}
}

/// Injects side effects to be performed upon the specified signal events.
public func on<T, E>(started: (() -> ())? = nil, event: (Event<T, E> -> ())? = nil, next: (T -> ())? = nil, error: (E -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil, terminated: (() -> ())? = nil, disposed: (() -> ())? = nil)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	return SignalProducer { observer, compositeDisposable in
		started?()
		disposed.map(compositeDisposable.addDisposable)

		producer.startWithSignal { signal, disposable in
			compositeDisposable.addDisposable(disposable)

			let innerObserver = Signal<T, E>.Observer { receivedEvent in
				event?(receivedEvent)

				switch receivedEvent {
				case let .Next(value):
					next?(value.unbox)

				case let .Error(err):
					error?(err.unbox)

				case .Completed:
					completed?()

				case .Interrupted:
					interrupted?()
				}

				if receivedEvent.isTerminating {
					terminated?()
				}

				observer.put(receivedEvent)
			}

			signal.observe(innerObserver)
		}
	}
}

/// Starts the returned signal on the given Scheduler.
///
/// This implies that any side effects embedded in the producer will be
/// performed on the given scheduler as well.
///
/// Events may still be sent upon other schedulers—this merely affects where
/// the `start()` method is run.
public func startOn<T, E>(scheduler: SchedulerType) -> SignalProducer<T, E> -> SignalProducer<T, E> {
	return { producer in
		return SignalProducer { observer, compositeDisposable in
			let schedulerDisposable = scheduler.schedule {
				producer.startWithSignal { signal, signalDisposable in
					compositeDisposable.addDisposable(signalDisposable)
					signal.observe(observer)
				}
			}

			compositeDisposable.addDisposable(schedulerDisposable)
		}
	}
}

/// Combines the latest value of the receiver with the latest value from
/// the given producer.
///
/// Signals started by the returned producer will not send a value until both
/// inputs have sent at least one value each.
public func combineLatestWith<T, U, E>(otherSignalProducer: SignalProducer<U, E>)(producer: SignalProducer<T, E>) -> SignalProducer<(T, U), E> {
	return producer.lift(combineLatestWith)(otherSignalProducer)
}

/// Zips elements of two signal producers into pairs. The elements of any Nth
/// pair are the Nth elements of the two input producers.
public func zipWith<T, U, E>(otherSignalProducer: SignalProducer<U, E>)(producer: SignalProducer<T, E>) -> SignalProducer<(T, U), E> {
	return producer.lift(zipWith)(otherSignalProducer)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>) -> SignalProducer<(A, B), Error> {
	return a |> combineLatestWith(b)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>) -> SignalProducer<(A, B, C), Error> {
	return combineLatest(a, b)
		|> combineLatestWith(c)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>) -> SignalProducer<(A, B, C, D), Error> {
	return combineLatest(a, b, c)
		|> combineLatestWith(d)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, E, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>) -> SignalProducer<(A, B, C, D, E), Error> {
	return combineLatest(a, b, c, d)
		|> combineLatestWith(e)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, E, F, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>) -> SignalProducer<(A, B, C, D, E, F), Error> {
	return combineLatest(a, b, c, d, e)
		|> combineLatestWith(f)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, E, F, G, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>) -> SignalProducer<(A, B, C, D, E, F, G), Error> {
	return combineLatest(a, b, c, d, e, f)
		|> combineLatestWith(g)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, E, F, G, H, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>, h: SignalProducer<H, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H), Error> {
	return combineLatest(a, b, c, d, e, f, g)
		|> combineLatestWith(h)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, E, F, G, H, I, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>, h: SignalProducer<H, Error>, i: SignalProducer<I, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I), Error> {
	return combineLatest(a, b, c, d, e, f, g, h)
		|> combineLatestWith(i)
		|> map(repack)
}

/// Combines the values of all the given producers, in the manner described by
/// `combineLatestWith`.
public func combineLatest<A, B, C, D, E, F, G, H, I, J, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>, h: SignalProducer<H, Error>, i: SignalProducer<I, Error>, j: SignalProducer<J, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I, J), Error> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		|> combineLatestWith(j)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>) -> SignalProducer<(A, B), Error> {
	return a |> zipWith(b)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>) -> SignalProducer<(A, B, C), Error> {
	return zip(a, b)
		|> zipWith(c)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>) -> SignalProducer<(A, B, C, D), Error> {
	return zip(a, b, c)
		|> zipWith(d)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, E, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>) -> SignalProducer<(A, B, C, D, E), Error> {
	return zip(a, b, c, d)
		|> zipWith(e)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, E, F, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>) -> SignalProducer<(A, B, C, D, E, F), Error> {
	return zip(a, b, c, d, e)
		|> zipWith(f)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, E, F, G, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>) -> SignalProducer<(A, B, C, D, E, F, G), Error> {
	return zip(a, b, c, d, e, f)
		|> zipWith(g)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, E, F, G, H, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>, h: SignalProducer<H, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H), Error> {
	return zip(a, b, c, d, e, f, g)
		|> zipWith(h)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, E, F, G, H, I, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>, h: SignalProducer<H, Error>, i: SignalProducer<I, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I), Error> {
	return zip(a, b, c, d, e, f, g, h)
		|> zipWith(i)
		|> map(repack)
}

/// Zips the values of all the given producers, in the manner described by
/// `zipWith`.
public func zip<A, B, C, D, E, F, G, H, I, J, Error>(a: SignalProducer<A, Error>, b: SignalProducer<B, Error>, c: SignalProducer<C, Error>, d: SignalProducer<D, Error>, e: SignalProducer<E, Error>, f: SignalProducer<F, Error>, g: SignalProducer<G, Error>, h: SignalProducer<H, Error>, i: SignalProducer<I, Error>, j: SignalProducer<J, Error>) -> SignalProducer<(A, B, C, D, E, F, G, H, I, J), Error> {
	return zip(a, b, c, d, e, f, g, h, i)
		|> zipWith(j)
		|> map(repack)
}

/// Forwards the latest value from `producer` whenever `sampler` sends a Next
/// event.
///
/// If `sampler` fires before a value has been observed on `producer`, nothing
/// happens.
///
/// Returns a producer that will send values from `producer`, sampled (possibly
/// multiple times) by `sampler`, then complete once both inputs have completed.
public func sampleOn<T, E>(sampler: SignalProducer<(), NoError>)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	return producer.lift(sampleOn)(sampler)
}

/// Forwards events from `producer` until `trigger` sends a Next or Completed
/// event, at which point the returned producer will complete.
public func takeUntil<T, E>(trigger: SignalProducer<(), NoError>)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	return producer.lift(takeUntil)(trigger)
}

/// Forwards events from `producer` until `replacement` begins sending events.
///
/// Returns a signal which passes through `next`s and `error` from `producer`
/// until `replacement` sends an event, at which point the returned producer
/// will send that event and switch to passing through events from `replacement`
/// instead, regardless of whether `producer` has sent events already.
public func takeUntilReplacement<T, E>(replacement: SignalProducer<T, E>)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	return producer.lift(takeUntilReplacement)(replacement)
}

/// Catches any error that may occur on the input producer, then starts a new
/// producer in its place.
public func catch<T, E, F>(handler: E -> SignalProducer<T, F>)(producer: SignalProducer<T, E>) -> SignalProducer<T, F> {
	return SignalProducer { observer, disposable in
		let serialDisposable = SerialDisposable()
		disposable.addDisposable(serialDisposable)

		producer.startWithSignal { signal, signalDisposable in
			serialDisposable.innerDisposable = signalDisposable

			signal.observe(next: { value in
				sendNext(observer, value)
			}, error: { error in
				handler(error).startWithSignal { signal, signalDisposable in
					serialDisposable.innerDisposable = signalDisposable
					signal.observe(observer)
				}
			}, completed: {
				sendCompleted(observer)
			}, interrupted: {
				sendInterrupted(observer)
			})
		}
	}
}

/// Describes how multiple signals or producers should be joined together.
public enum JoinStrategy: Equatable {
	/// The signals should be merged, so that any value received on any of the
	/// input signals will be forwarded immediately to the output signal.
	///
	/// The resulting signal will complete only when all inputs have completed.
	case Merge

	/// The signals should be concatenated, so that their values are sent in the
	/// order of the signals themselves.
	///
	/// The resulting signal will complete only when all inputs have completed.
	case Concat

	/// Only the events from the latest input signal should be considered for
	/// the output. Any signals received before that point will be disposed of.
	///
	/// The resulting signal will complete only when the signal-of-signals and
	/// the latest signal has completed.
	case Latest
}

public func == (lhs: JoinStrategy, rhs: JoinStrategy) -> Bool {
	switch (lhs, rhs) {
	case (.Merge, .Merge), (.Concat, .Concat), (.Latest, .Latest):
		return true

	default:
		return false
	}
}

extension JoinStrategy: Printable {
	public var description: String {
		switch self {
		case .Merge:
			return "merge"

		case .Concat:
			return "concatenate"

		case .Latest:
			return "latest"
		}
	}
}

/// Joins together the inner producers sent upon `producer` according to the
/// semantics of the given strategy.
///
/// If `producer` or an active inner producer emits an error, the returned
/// producer will forward that error immediately.
public func join<T, E>(strategy: JoinStrategy)(producer: SignalProducer<SignalProducer<T, E>, E>) -> SignalProducer<T, E> {
	switch strategy {
	case .Merge:
		return producer |> merge

	case .Concat:
		return producer |> concat

	case .Latest:
		return producer |> switchToLatest
	}
}

/// Maps each event from `producer` to a new producer, then joins the resulting
/// producers together according to the semantics of the given strategy.
///
/// If `producer` or any of the created producers emit an error, the returned
/// producer will forward that error immediately.
public func joinMap<T, U, E>(strategy: JoinStrategy, transform: T -> SignalProducer<U, E>)(producer: SignalProducer<T, E>) -> SignalProducer<U, E> {
	return producer |> map(transform) |> join(strategy)
}

/// Returns a signal which sends all the values from each signal emitted from
/// `producer`, waiting until each inner signal completes before beginning to
/// send the values from the next inner signal.
///
/// If any of the inner signals emit an error, the returned signal will emit
/// that error.
///
/// The returned signal completes only when `producer` and all signals
/// emitted from `producer` complete.
private func concat<T, E>(producer: SignalProducer<SignalProducer<T, E>, E>) -> SignalProducer<T, E> {
	return SignalProducer { observer, disposable in
		let state = ConcatState(observer: observer, disposable: disposable)

		producer.startWithSignal { signal, signalDisposable in
			signal.observe(next: { innerSignalProducer in
				state.enqueueSignalProducer(innerSignalProducer)
			}, error: { error in
				sendError(observer, error)
			}, completed: {
				// Add one last producer to the queue, whose sole job is to
				// "turn out the lights" by completing `observer`.
				let completion: SignalProducer<T, E> = .empty |> on(completed: {
					sendCompleted(observer)
				})

				state.enqueueSignalProducer(completion)
			}, interrupted: {
				sendInterrupted(observer)
			})

			disposable.addDisposable(signalDisposable)
		}
	}
}

private final class ConcatState<T, E: ErrorType> {
	/// The observer of a started `concat` producer.
	let observer: Signal<T, E>.Observer

	/// The top level disposable of a started `concat` producer.
	let disposable: CompositeDisposable

	/// The active producer, if any, and the producers waiting to be started.
	let queuedSignalProducers: Atomic<[SignalProducer<T, E>]> = Atomic([])

	init(observer: Signal<T, E>.Observer, disposable: CompositeDisposable) {
		self.observer = observer
		self.disposable = disposable
	}

	func enqueueSignalProducer(producer: SignalProducer<T, E>) {
		var shouldStart = true

		queuedSignalProducers.modify { (var queue) in
			// An empty queue means the concat is idle, ready & waiting to start
			// the next producer.
			shouldStart = queue.isEmpty
			queue.append(producer)
			return queue
		}

		if shouldStart {
			startNextSignalProducer(producer)
		}
	}

	func dequeueSignalProducer() -> SignalProducer<T, E>? {
		var nextSignalProducer: SignalProducer<T, E>?

		queuedSignalProducers.modify { (var queue) in
			// Active producers remain in the queue until completed. Since
			// dequeueing happens at completion of the active producer, the
			// first producer in the queue can be removed.
			queue.removeAtIndex(0)
			nextSignalProducer = queue.first
			return queue
		}

		return nextSignalProducer
	}

	/// Subscribes to the given signal producer.
	func startNextSignalProducer(signalProducer: SignalProducer<T, E>) {
		signalProducer.startWithSignal { signal, disposable in
			self.disposable.addDisposable(disposable)

			signal.observe(Signal.Observer { event in
				switch event {
				case .Completed:
					if let nextSignalProducer = self.dequeueSignalProducer() {
						self.startNextSignalProducer(nextSignalProducer)
					}

				default:
					self.observer.put(event)
				}
			})
		}
	}
}

/// Create a fix point to enable recursive calling of a closure.
private func fix<T, U>(f: (T -> U) -> T -> U) -> T -> U {
	return { f(fix(f))($0) }
}

/// `concat`s `next` onto `producer`.
public func concat<T, E>(next: SignalProducer<T, E>)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	return SignalProducer(values: [producer, next]) |> join(.Concat)
}

/// Returns a producer that forwards values from the latest producer sent on
/// `producer`, ignoring values sent on previous inner producers.
///
/// An error sent on `producer` or the latest inner producer will be sent on the
/// returned producer.
///
/// The returned producer completes when `producer` and the latest inner
/// producer have both completed.
private func switchToLatest<T, E>(producer: SignalProducer<SignalProducer<T, E>, E>) -> SignalProducer<T, E> {
	return SignalProducer<T, E> { sink, disposable in
		producer.startWithSignal { outerSignal, outerDisposable in
			disposable.addDisposable(outerDisposable)

			let latestInnerDisposable = SerialDisposable()
			disposable.addDisposable(latestInnerDisposable)

			let state = Atomic(LatestState<T, E>(outerSignalComplete: false, latestIncompleteSignal: nil))
			let updateState = { (action: LatestState<T, E> -> LatestState<T, E>) -> () in
				state.modify(action)
				if state.value.isComplete {
					sendCompleted(sink)
				}
			}

			outerSignal.observe(
				next: { innerProducer in
					innerProducer.startWithSignal { innerSignal, innerDisposable in
						state.modify { state in
							return state.isComplete
								? state
								: LatestState(
									outerSignalComplete: state.outerSignalComplete,
									latestIncompleteSignal: innerSignal)
						}

						// Don't dispose of the previous signal until we've
						// registered this new signal as the latest, or else we
						// may inadvertently send Interrupted to our observer.
						latestInnerDisposable.innerDisposable = innerDisposable

						innerSignal.observe(SinkOf { event in
							switch event {
							case .Completed:
								updateState { state in
									return state.isLatestIncompleteSignal(innerSignal)
										? LatestState(
											outerSignalComplete: state.outerSignalComplete,
											latestIncompleteSignal: nil)
										: state
								}

							default:
								state.withValue { value -> () in
									if value.isLatestIncompleteSignal(innerSignal) {
										sink.put(event)
									}
								}
							}
						})
					}
				}, error: { error in
					sendError(sink, error)
				}, completed: {
					updateState { state in
						LatestState(
							outerSignalComplete: true,
							latestIncompleteSignal: state.latestIncompleteSignal)
					}
				}, interrupted: {
					sendInterrupted(sink)
				})
		}
	}
}

private struct LatestState<T, E: ErrorType> {
	let outerSignalComplete: Bool
	let latestIncompleteSignal: Signal<T, E>?

	func isLatestIncompleteSignal(signal: Signal<T, E>) -> Bool {
		if let latestIncompleteSignal = latestIncompleteSignal {
			return latestIncompleteSignal === signal
		} else {
			return false
		}
	}

	var isComplete: Bool {
		return outerSignalComplete && latestIncompleteSignal == nil
	}
}

/// Merges a `producer` of SignalProducers down into a single producer, biased toward the producers
/// added earlier. Returns a SignalProducer that will forward signals from the original producers
/// as they arrive.
private func merge<T, E>(producer: SignalProducer<SignalProducer<T, E>, E>) -> SignalProducer<T, E> {
	return SignalProducer<T, E> { relayObserver, relayDisposable in
		let inFlight = Atomic(1)

		let decrementInFlight: () -> () = {
			let orig = inFlight.modify { $0 - 1 }
			if orig == 1 {
				sendCompleted(relayObserver)
			}
		}

		producer.startWithSignal { producerSignal, producerDisposable in
			relayDisposable.addDisposable(producerDisposable)

			producerSignal.observe(next: { innerProducer in
				innerProducer.startWithSignal { innerProducerSignal, innerProducerDisposable in
					inFlight.modify { $0 + 1 }

					let innerProducerHandle = relayDisposable.addDisposable(innerProducerDisposable)

					innerProducerSignal.observe(Signal<T,E>.Observer { event in
						if event.isTerminating {
							innerProducerHandle.remove()
						}

						switch event {
						case .Completed:
							decrementInFlight()

						default:
							relayObserver.put(event)
						}
					})
				}
			}, error: { error in
				sendError(relayObserver, error)
			}, completed: {
				decrementInFlight()
			}, interrupted: {
				sendInterrupted(relayObserver)
			})
		}
	}
}

/// Repeats `producer` a total of `count` times.
/// Repeating `1` times results in a equivalent signal producer.
public func times<T, E>(count: Int)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	precondition(count >= 0)

	if count == 0 {
		return .empty
	} else if count == 1 {
		return producer
	}

	return SignalProducer { observer, disposable in
		let serialDisposable = SerialDisposable()
		disposable.addDisposable(serialDisposable)

		var remainingTimes = count

		let iterate = fix { recur in
			{
				producer.startWithSignal { signal, signalDisposable in
					serialDisposable.innerDisposable = signalDisposable

					signal.observe(Signal.Observer { event in
						switch event {
						case .Completed:
							if --remainingTimes > 0 {
								recur()
							} else {
								sendCompleted(observer)
							}

						default:
							observer.put(event)
						}
					})
				}
			}
		}

		iterate()
	}
}

/// Ignores errors up to `count` times.
public func retry<T, E>(count: Int)(producer: SignalProducer<T, E>) -> SignalProducer<T, E> {
	precondition(count >= 0)

	if count == 0 {
		return producer
	} else {
		return producer |> catch { _ in
			producer |> retry(count - 1)
		}
	}
}

/// Waits for completion of `producer`, *then* forwards all events from
/// `replacement`. Any error sent from `producer` is forwarded immediately, in
/// which case `replacement` will not be started, and none of its events will be
/// be forwarded. All values sent from `producer` are ignored.
public func then<T, U, E>(replacement: SignalProducer<U, E>)(producer: SignalProducer<T, E>) -> SignalProducer<U, E> {
	let relay = SignalProducer<U, E> { observer, observerDisposable in
		producer.startWithSignal { signal, signalDisposable in
			observerDisposable.addDisposable(signalDisposable)

			signal.observe(error: { error in
				sendError(observer, error)
			}, completed: {
				sendCompleted(observer)
			}, interrupted: {
				sendInterrupted(observer)
			})
		}
	}

	return relay |> concat(replacement)
}

/// Starts the producer, then blocks, waiting for the first value.
public func first<T, E>(producer: SignalProducer<T, E>) -> Result<T, E>? {
	return producer |> take(1) |> single
}

/// Starts the producer, then blocks, waiting for events: Next and Completed.
/// When a single value or error is sent, the returned `Result` will represent
/// those cases. However, when no values are sent, or when more than one value
/// is sent, `nil` will be returned.
public func single<T, E>(producer: SignalProducer<T, E>) -> Result<T, E>? {
	let semaphore = dispatch_semaphore_create(0)
	var result: Result<T, E>?

	producer
		|> take(2)
		|> start(next: { value in
			if result != nil {
				// Move into failure state after recieving another value.
				result = nil
				return
			}

			result = success(value)
		}, error: { error in
			result = failure(error)
			dispatch_semaphore_signal(semaphore)
		}, completed: {
			_ = dispatch_semaphore_signal(semaphore)
		}, interrupted: {
			_ = dispatch_semaphore_signal(semaphore)
		})

	dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
	return result
}

/// Starts the producer, then blocks, waiting for the last value.
public func last<T, E>(producer: SignalProducer<T, E>) -> Result<T, E>? {
	return producer |> takeLast(1) |> single
}

/// Starts the producer, then blocks, waiting for completion.
public func wait<T, E>(producer: SignalProducer<T, E>) -> Result<(), E> {
	let result = producer |> then(SignalProducer(value: ())) |> last
	return result ?? success(())
}

/// SignalProducer.startWithSignal() as a free function, for easier use with |>.
public func startWithSignal<T, E>(setUp: (Signal<T, E>, Disposable) -> ())(producer: SignalProducer<T, E>) -> () {
	return producer.startWithSignal(setUp)
}

/// SignalProducer.start() as a free function, for easier use with |>.
public func start<T, E, S: SinkType where S.Element == Event<T, E>>(sink: S)(producer: SignalProducer<T, E>) -> Disposable {
	return producer.start(sink)
}

/// SignalProducer.start() as a free function, for easier use with |>.
public func start<T, E>(next: (T -> ())? = nil, error: (E -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil)(producer: SignalProducer<T, E>) -> Disposable {
	return producer.start(next: next, error: error, completed: completed, interrupted: interrupted)
}
