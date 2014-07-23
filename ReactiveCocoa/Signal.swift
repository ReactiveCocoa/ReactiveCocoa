//
//  Signal.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// A push-driven stream that sends the same values to all observers.
///
/// Unlike the Consumers of a Producer, all observers of a Signal will see the
/// same version of events.
public final class Signal<T> {
	private let _queue = dispatch_queue_create("com.github.ReactiveCocoa.Signal", DISPATCH_QUEUE_CONCURRENT)
	private let _generator: SinkOf<T> -> ()

	private var _current: T? = nil
	private var _observers = Bag<SinkOf<T>>()

	/// The current (most recent) value of the Signal.
	public var current: T {
		var value: T? = nil

		dispatch_sync(_queue) {
			value = self._current
		}

		return value!
	}
	
	/// Initializes a Signal with the given starting value, and an action to
	/// perform to begin observing future changes.
	public init(initialValue: T, generator: SinkOf<T> -> ()) {
		_current = initialValue

		// Save the generator closure so that anything it captures (e.g.,
		// another Signal dependency) remains alive while this Signal object is
		// too.
		_generator = generator

		_generator(SinkOf { [weak self] value in
			if let strongSelf = self {
				dispatch_barrier_sync(strongSelf._queue) {
					strongSelf._current = value

					for sink in strongSelf._observers {
						sink.put(value)
					}
				}
			}
		})
	}

	/// Creates a Signal that will always have the same value.
	public class func constant(value: T) -> Signal<T> {
		return Signal(initialValue: value) { _ in }
	}

	/// Creates a repeating timer of the given interval, sending updates on the
	/// given scheduler.
	public class func interval(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval = 0) -> Signal<NSDate> {
		let startDate = NSDate()

		return Signal<NSDate>(initialValue: startDate) { sink in
			scheduler.scheduleAfter(startDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
				sink.put(NSDate())
			}
			
			return ()
		}
	}

	/// Creates a Signal that can be controlled by sending values to the
	/// returned Sink.
	public class func pipeWithInitialValue(initialValue: T) -> (Signal<T>, SinkOf<T>) {
		var sink: SinkOf<T>? = nil
		let signal = Signal(initialValue: initialValue) { s in sink = s }

		assert(sink)
		return (signal, sink!)
	}

	/// Notifies `observer` about all changes to the receiver's value.
	///
	/// Returns a Disposable which can be disposed of to stop notifying
	/// `observer` of future changes.
	public func observe<S: Sink where S.Element == T>(observer: S) -> Disposable {
		let sink = SinkOf<T>(observer)
		var token: Bag.RemovalToken? = nil

		dispatch_barrier_sync(_queue) {
			token = self._observers.insert(sink)
			sink.put(self._current!)
		}

		return ActionDisposable {
			// Retain `self` strongly so that observers can hold onto the Signal
			// _or_ the Disposable to ensure the receipt of values.
			dispatch_barrier_async(self._queue) {
				self._observers.removeValueForToken(token!)
			}
		}
	}

	/// Convenience function to invoke observe() with a Sink that will pass
	/// values to the given closure.
	public func observe(observer: T -> ()) -> Disposable {
		return observe(SinkOf(observer))
	}

	/// Unwraps all Optional values in the stream, silently ignoring any that
	/// are `nil`.
	///
	/// evidence     - Used to prove to the typechecker that the receiver is
	///                a stream of optionals. Simply pass in the `identity`
	///                function.
	/// initialValue - A default value for the returned stream, in case the
	///                receiver's current value is `nil`, which would otherwise
	///                result in a missing value for the returned stream.
	public func unwrapOptionals<U>(evidence: Signal<T> -> Signal<U?>, initialValue: U) -> Signal<U> {
		return Signal<U>(initialValue: initialValue) { sink in
			evidence(self).observe { maybeValue in
				if let value = maybeValue {
					sink.put(value)
				}
			}

			return ()
		}
	}

	/// Forcibly unwraps all Optional values in the stream.
	///
	/// Use only when you're completely sure that the signal will never contain
	/// `nil`, because any `nil` values will result in a runtime error.
	///
	/// evidence     - Used to prove to the typechecker that the receiver is
	///                a stream of optionals. Simply pass in the `identity`
	///                function.
	public func forceUnwrapOptionals<U>(evidence: Signal<T> -> Signal<U?>) -> Signal<U> {
		let evidencedSelf = evidence(self)

		return Signal<U>(initialValue: evidencedSelf.current!) { sink in
			evidencedSelf.observe { maybeValue in
				sink.put(maybeValue!)
			}

			return ()
		}
	}

	/// Merges a Signal of Signals into a single stream, biased toward
	/// the Signals added earlier.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a Signal that will forward changes from the original streams
	/// as they arrive, starting with earlier ones.
	public func merge<U>(evidence: Signal<T> -> Signal<Signal<U>>) -> Signal<U> {
		return Signal<U?>(initialValue: nil) { sink in
			let streams = Atomic<[Signal<U>]>([])

			evidence(self).observe { stream in
				streams.modify { (var arr) in
					arr.append(stream)
					return arr
				}

				stream.observe { value in sink.put(value) }
			}
		}.forceUnwrapOptionals(identity)
	}

	/// Switches on a Signal of Signals, forwarding values from the
	/// latest inner stream.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a Signal that will forward changes only from the latest
	/// Signal sent upon the receiver.
	public func switchToLatest<U>(evidence: Signal<T> -> Signal<Signal<U>>) -> Signal<U> {
		return Signal<U?>(initialValue: nil) { sink in
			let latestDisposable = SerialDisposable()

			evidence(self).observe { stream in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = stream.observe { value in sink.put(value) }
			}
		}.forceUnwrapOptionals(identity)
	}

	/// Maps each value in the stream to a new value.
	public func map<U>(f: T -> U) -> Signal<U> {
		return Signal<U?>(initialValue: nil) { sink in
			self.observe { value in sink.put(f(value)) }
			return ()
		}.forceUnwrapOptionals(identity)
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
	public func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Signal<U> {
		let previous = Atomic(initialValue)

		return Signal<U?>(initialValue: nil) { sink in
			self.observe { value in
				let newValue = f(previous.value, value)
				sink.put(newValue)

				previous.value = newValue
			}

			return ()
		}.forceUnwrapOptionals(identity)
	}

	/// Returns a stream that will yield the first `count` values from the
	/// receiver, where `count` is greater than zero.
	public func take(count: Int) -> Signal<T> {
		assert(count > 0)

		let soFar = Atomic(0)

		return Signal(initialValue: self.current) { sink in
			let selfDisposable = SerialDisposable()

			selfDisposable.innerDisposable = self.observe { value in
				let orig = soFar.modify { $0 + 1 }
				if orig < count {
					sink.put(value)
				} else {
					selfDisposable.dispose()
				}
			}
		}
	}

	/// Returns a stream that will yield values from the receiver while `pred`
	/// remains `true`. If no values pass the predicate, the resulting signal
	/// will be `nil`.
	public func takeWhile(pred: T -> Bool) -> Signal<T?> {
		return Signal<T?>(initialValue: nil) { sink in
			let selfDisposable = SerialDisposable()

			selfDisposable.innerDisposable = self.observe { value in
				if pred(value) {
					sink.put(value)
				} else {
					selfDisposable.dispose()
				}
			}
		}
	}

	/// Combines each value in the stream with its preceding value, starting
	/// with `initialValue`.
	public func combinePrevious(initialValue: T) -> Signal<(T, T)> {
		let previous = Atomic(initialValue)

		return Signal<(T, T)?>(initialValue: nil) { sink in
			self.observe { value in
				let orig = previous.swap(value)
				sink.put((orig, value))
			}

			return ()
		}.forceUnwrapOptionals(identity)
	}

	/// Returns a stream that will replace the first `count` values from the
	/// receiver with `nil`, then forward everything afterward.
	public func skip(count: Int) -> Signal<T?> {
		let soFar = Atomic(0)

		return skipWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	/// Returns a stream that will replace values from the receiver with `nil`
	/// while `pred` remains `true`, then forward everything afterward.
	public func skipWhile(pred: T -> Bool) -> Signal<T?> {
		return Signal<T?>(initialValue: nil) { sink in
			let skipping = Atomic(true)

			self.observe { value in
				if skipping.value && pred(value) {
					sink.put(nil)
				} else {
					skipping.value = false
					sink.put(value)
				}
			}

			return ()
		}
	}

	/// Buffers values yielded by the receiver, preserving them for future
	/// consumers.
	///
	/// capacity - If not nil, the maximum number of values to buffer. If more
	///            are received, the earliest values are dropped and won't be
	///            given to consumers in the future.
	///
	/// Returns a Producer over the buffered values, and a Disposable which
	/// can be used to cancel all further buffering.
	public func buffer(capacity: Int? = nil) -> (Producer<T>, Disposable) {
		let queue = dispatch_queue_create("com.github.ReactiveCocoa.Signal.buffer", DISPATCH_QUEUE_CONCURRENT)
		var compositeDisposable = CompositeDisposable()

		var bufferedValues: [T] = []
		let bufferDisposable = self.observe { value in
			// Append to the buffer synchronously, so that Consumers attempting
			// to connect simultaneously (below) see a consistent view of
			// buffered vs. future values.
			dispatch_barrier_sync(queue) {
				bufferedValues.append(value)

				if let c = capacity {
					while bufferedValues.count > c {
						bufferedValues.removeAtIndex(0)
					}
				}
			}
		}

		compositeDisposable.addDisposable(bufferDisposable)

		let producer = Producer<T> { consumer in
			var observeDisposable: Disposable? = nil

			dispatch_sync(queue) {
				// Send all values accumulated to this point…
				for value in bufferedValues {
					consumer.put(.Next(Box(value)))
				}

				// then all future changes as well.
				observeDisposable = self.skip(1).observe { maybeValue in
					if let value = maybeValue {
						consumer.put(.Next(Box(value)))
					}
				}
			}

			let completeDisposable = ActionDisposable {
				// Stop observing value changes, and terminate the Consumer.
				observeDisposable!.dispose()
				consumer.put(.Completed)

				// Remove this disposable from the CompositeDisposable to
				// prevent infinite resource growth.
				compositeDisposable.pruneDisposed()
			}

			consumer.disposable.addDisposable(completeDisposable)
			compositeDisposable.addDisposable(completeDisposable)
		}

		return (producer, compositeDisposable)
	}

	/// Preserves only the values of the stream that pass the given predicate.
	public func filter(pred: T -> Bool) -> Signal<T?> {
		return Signal<T?>(initialValue: nil) { sink in
			self.observe { value in
				if pred(value) {
					sink.put(value)
				} else {
					sink.put(nil)
				}
			}

			return ()
		}
	}

	/// Skips all consecutive, repeating values in the stream, forwarding only
	/// the first occurrence.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            values which are `Equatable`. Simply pass in the `identity`
	///            function.
	public func skipRepeats<U: Equatable>(evidence: Signal<T> -> Signal<U>) -> Signal<U> {
		let evidencedSelf = evidence(self)

		return Signal<U>(initialValue: evidencedSelf.current) { sink in
			let maybePrevious = Atomic<U?>(nil)

			evidencedSelf.observe { current in
				if let previous = maybePrevious.swap(current) {
					if current == previous {
						return
					}
				}

				sink.put(current)
			}

			return ()
		}
	}

	/// Combines the receiver with the given stream, forwarding the latest
	/// updates to either.
	///
	/// Returns a Signal which will send a new value whenever the receiver
	/// or `stream` changes.
	public func combineLatestWith<U>(stream: Signal<U>) -> Signal<(T, U)> {
		return Signal<(T, U)>(initialValue: (self.current, stream.current)) { sink in
			// FIXME: This implementation is probably racey.
			self.observe { [unowned stream] value in sink.put(value, stream.current) }
			stream.observe { [unowned self] value in sink.put(self.current, value) }
		}
	}

	/// Forwards the current value from the receiver whenever `sampler` sends
	/// a value.
	public func sampleOn<U>(sampler: Signal<U>) -> Signal<T> {
		return Signal(initialValue: self.current) { sink in
			sampler.observe { _ in sink.put(self.current) }
			return ()
		}
	}

	/// Delays values by the given interval, forwarding them on the given
	/// scheduler.
	///
	/// Returns a Signal that will default to `nil`, then send the
	/// receiver's values after injecting the specified delay.
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> Signal<T?> {
		return Signal<T?>(initialValue: nil) { sink in
			self.observe { value in
				scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) { sink.put(value) }
				return ()
			}

			return ()
		}
	}

	/// Throttle values sent by the receiver, so that at least `interval`
	/// seconds pass between each, then forwards them on the given scheduler.
	///
	/// If multiple values are received before the interval has elapsed, the
	/// latest value is the one that will be passed on.
	public func throttle(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> Signal<T> {
		return Signal(initialValue: self.current) { sink in
			let previousDate = Atomic(NSDate())
			let disposable = SerialDisposable()

			self.observe { value in
				disposable.innerDisposable = nil

				let now = NSDate()
				let (_, scheduleDate) = previousDate.modify { date -> (NSDate, NSDate) in
					if now.timeIntervalSinceDate(date) >= interval {
						return (now, now)
					} else {
						return (date, date.dateByAddingTimeInterval(interval))
					}
				}

				disposable.innerDisposable = scheduler.scheduleAfter(scheduleDate) { sink.put(value) }
			}
		}
	}

	/// Yields all values on the given scheduler, instead of whichever
	/// scheduler they originally changed upon.
	///
	/// Returns a Signal that will default to `nil`, then send the
	/// receiver's values after being scheduled.
	public func deliverOn(scheduler: Scheduler) -> Signal<T?> {
		return Signal<T?>(initialValue: nil) { sink in
			self.observe { value in
				scheduler.schedule { sink.put(value) }
				return ()
			}

			return ()
		}
	}

	/// Returns a Promise that will wait for the first value from the receiver
	/// that passes the given predicate.
	public func firstPassingTest(pred: T -> Bool) -> Promise<T> {
		return Promise { sink in
			self.take(1).observe { value in
				if pred(value) {
					sink.put(value)
				}
			}

			return ()
		}
	}

	/// Applies the latest function from the given signal to the values in the
	/// receiver.
	public func apply<U>(stream: Signal<T -> U>) -> Signal<U> {
		// FIXME: This should use combineLatestWith, but attempting to do so
		// crashes the compiler.
		return Signal<U>(initialValue: stream.current(self.current)) { sink in
			// FIXME: This implementation is probably racey.
			self.observe { [unowned stream] value in sink.put(stream.current(value)) }
			stream.observe { [unowned self] f in sink.put(f(self.current)) }
		}
	}
}
