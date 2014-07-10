//
//  Signal.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A push-driven stream that sends the same values to all observers.
@final class Signal<T> {
	let _queue = dispatch_queue_create("com.github.ReactiveCocoa.Signal", DISPATCH_QUEUE_CONCURRENT)
	var _current: T? = nil
	var _observers: [Box<SinkOf<T>>] = []

	/// The current (most recent) value of the Signal.
	var current: T {
		get {
			var value: T? = nil

			dispatch_sync(_queue) {
				value = self._current
			}

			return value!
		}
	}
	
	/// Initializes a Signal with the given starting value, and an action to
	/// perform to begin observing future changes.
	init(initialValue: T, generator: SinkOf<T> -> ()) {
		_current = initialValue

		generator(SinkOf { value in
			dispatch_barrier_sync(self._queue) {
				self._current = value

				for sinkBox in self._observers {
					sinkBox.value.put(value)
				}
			}
		})
	}

	/// Creates a Signal that will always have the same value.
	class func constant(value: T) -> Signal<T> {
		return Signal(initialValue: value) { _ in }
	}

	/// Creates a repeating timer of the given interval, sending updates on the
	/// given scheduler.
	class func interval(interval: NSTimeInterval, onScheduler scheduler: RepeatableScheduler, withLeeway leeway: NSTimeInterval = 0) -> Signal<NSDate> {
		let startDate = NSDate()

		return Signal<NSDate>(initialValue: startDate) { sink in
			scheduler.scheduleAfter(startDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
				sink.put(NSDate())
			}
			
			return ()
		}
	}

	/// Notifies `observer` about all changes to the receiver's value.
	///
	/// Returns a Disposable which can be disposed of to stop notifying
	/// `observer` of future changes.
	func observe<S: Sink where S.Element == T>(observer: S) -> Disposable {
		let box = Box(SinkOf<T>(observer))

		dispatch_barrier_sync(_queue) {
			self._observers.append(box)
			box.value.put(self._current!)
		}

		return ActionDisposable {
			dispatch_barrier_async(self._queue) {
				self._observers = removeObjectIdenticalTo(box, fromArray: self._observers)
			}
		}
	}

	/// Convenience function to invoke observe() with a Sink that will pass
	/// values to the given closure.
	func observe(observer: T -> ()) -> Disposable {
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
	func unwrapOptionals<U>(evidence: Signal<T> -> Signal<U?>, initialValue: U) -> Signal<U> {
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
	func forceUnwrapOptionals<U>(evidence: Signal<T> -> Signal<U?>) -> Signal<U> {
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
	///            a stream-of-streams. Simply pass in the `identity` function.
	///
	/// Returns a Signal that will forward changes from the original streams
	/// as they arrive, starting with earlier ones.
	func merge<U>(evidence: Signal<T> -> Signal<Signal<U>>) -> Signal<U> {
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
	///            a stream-of-streams. Simply pass in the `identity` function.
	///
	/// Returns a Signal that will forward changes only from the latest
	/// Signal sent upon the receiver.
	func switchToLatest<U>(evidence: Signal<T> -> Signal<Signal<U>>) -> Signal<U> {
		return Signal<U?>(initialValue: nil) { sink in
			let latestDisposable = SerialDisposable()

			evidence(self).observe { stream in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = stream.observe { value in sink.put(value) }
			}
		}.forceUnwrapOptionals(identity)
	}

	/// Maps each value in the stream to a new value.
	func map<U>(f: T -> U) -> Signal<U> {
		return Signal<U?>(initialValue: nil) { sink in
			self.observe { value in sink.put(f(value)) }
			return ()
		}.forceUnwrapOptionals(identity)
	}

	/// Combines all the values in the stream, forwarding the result of each
	/// intermediate combination step.
	func scan<U>(initialValue: U, _ f: (U, T) -> U) -> Signal<U> {
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
	func take(count: Int) -> Signal<T> {
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
	func takeWhile(pred: T -> Bool) -> Signal<T?> {
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
	func combinePrevious(initialValue: T) -> Signal<(T, T)> {
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
	func skip(count: Int) -> Signal<T?> {
		let soFar = Atomic(0)

		return skipWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	/// Returns a stream that will replace values from the receiver with `nil`
	/// while `pred` remains `true`, then forward everything afterward.
	func skipWhile(pred: T -> Bool) -> Signal<T?> {
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
	func buffer(capacity: Int? = nil) -> (Producer<T>, Disposable) {
		let buffer = EventBuffer<T>(capacity: capacity)

		let observationDisposable = self.observe { value in
			buffer.put(.Next(Box(value)))
		}

		let bufferDisposable = ActionDisposable {
			observationDisposable.dispose()

			// FIXME: This violates the buffer size, since it will now only
			// contain N - 1 values.
			buffer.put(.Completed)
		}

		return (buffer, bufferDisposable)
	}

	/// Preserves only the values of the stream that pass the given predicate.
	func filter(pred: T -> Bool) -> Signal<T?> {
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
	func skipRepeats<U: Equatable>(evidence: Signal<T> -> Signal<U>) -> Signal<U> {
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
	func combineLatestWith<U>(stream: Signal<U>) -> Signal<(T, U)> {
		return Signal<(T, U)>(initialValue: (self.current, stream.current)) { sink in
			// FIXME: This implementation is probably racey.
			self.observe { value in sink.put(value, stream.current) }
			stream.observe { value in sink.put(self.current, value) }
		}
	}

	/// Forwards the current value from the receiver whenever `sampler` sends
	/// a value.
	func sampleOn<U>(sampler: Signal<U>) -> Signal<T> {
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
	func delay(interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Signal<T?> {
		return Signal<T?>(initialValue: nil) { sink in
			self.observe { value in
				scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) { sink.put(value) }
				return ()
			}

			return ()
		}
	}

	/// Yields all values on the given scheduler, instead of whichever
	/// scheduler they originally changed upon.
	///
	/// Returns a Signal that will default to `nil`, then send the
	/// receiver's values after being scheduled.
	func deliverOn(scheduler: Scheduler) -> Signal<T?> {
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
	func firstPassingTest(pred: T -> Bool) -> Promise<T> {
		return Promise { sink in
			self.take(1).observe { value in
				if pred(value) {
					sink.put(value)
				}
			}

			return ()
		}
	}
}
