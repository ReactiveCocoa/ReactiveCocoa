//
//  HotSignal.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

/// A push-driven stream that sends the same values to all observers.
public final class HotSignal<T> {
	private let generator: SinkOf<T> -> ()

	private let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.HotSignal", DISPATCH_QUEUE_CONCURRENT)
	private var observers = Bag<SinkOf<T>>()

	/// Initializes a signal that will immediately perform the given action to
	/// begin generating its values.
	public init(_ generator: SinkOf<T> -> ()) {
		// Save the generator closure so that anything it captures (e.g.,
		// another signal dependency) remains alive while this signal object is
		// too.
		self.generator = generator
		self.generator(SinkOf { [weak self] value in
			if let strongSelf = self {
				dispatch_sync(strongSelf.queue) {
					for sink in strongSelf.observers {
						sink.put(value)
					}
				}
			}
		})
	}

	/// Notifies `observer` about new values from the receiver.
	///
	/// Returns a Disposable which can be disposed of to stop notifying
	/// `observer` of future changes.
	public func observe<S: SinkType where S.Element == T>(observer: S) -> Disposable {
		let sink = SinkOf<T>(observer)
		var token: RemovalToken? = nil

		dispatch_barrier_sync(queue) {
			token = self.observers.insert(sink)
		}

		return ActionDisposable {
			// Retain `self` strongly so that observers can hold onto the signal
			// _or_ the disposable to ensure the receipt of values.
			dispatch_barrier_async(self.queue) {
				self.observers.removeValueForToken(token!)
			}
		}
	}

	/// Convenience function to invoke observe() with a sink that will pass
	/// values to the given closure.
	public func observe(next: T -> ()) -> Disposable {
		return observe(SinkOf(next))
	}
}

/// Convenience constructors.
extension HotSignal {
	/// Creates a signal that will never send any values.
	public class func never() -> HotSignal {
		return HotSignal { _ in () }
	}

	/// Creates a repeating timer of the given interval, with a reasonable
	/// default leeway, sending updates on the given scheduler.
	public class func interval(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> HotSignal<NSDate> {
		// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
		// at least 10% of the timer interval.
		return self.interval(interval, onScheduler: scheduler, withLeeway: interval * 0.1)
	}

	/// Creates a repeating timer of the given interval, sending updates on the
	/// given scheduler.
	public class func interval(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval) -> HotSignal<NSDate> {
		let startDate = scheduler.currentDate

		return HotSignal<NSDate> { sink in
			scheduler.scheduleAfter(startDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
				sink.put(scheduler.currentDate)
			}

			return ()
		}
	}

	/// Creates a signal that can be controlled by sending values to the
	/// returned sink.
	public class func pipe() -> (HotSignal, SinkOf<T>) {
		// TODO: Keep the signal alive while the sink is, for operators like
		// replay().
		var sink: SinkOf<T>? = nil
		let signal = HotSignal { sink = $0 }

		assert(sink != nil)
		return (signal, sink!)
	}
}

/// Transformative operators.
extension HotSignal {
	/// Maps each value in the stream to a new value.
	public func map<U>(f: T -> U) -> HotSignal<U> {
		return HotSignal<U> { sink in
			self.observe { sink.put(f($0)) }
			return ()
		}
	}

	/// Combines all the values in the signal, forwarding the result of each
	/// intermediate combination step.
	public func scan<U>(#initial: U, _ f: (U, T) -> U) -> HotSignal<U> {
		let previous = Atomic(initial)

		return map { value in
			let newValue = f(previous.value, value)
			previous.value = newValue

			return newValue
		}
	}

	/// Returns a signal that will yield the first `count` values from the
	/// receiver.
	public func take(count: Int) -> HotSignal {
		if (count == 0) {
			return .never()
		}

		let soFar = Atomic(0)

		return HotSignal { sink in
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

	/// Returns a signal that will yield values from the receiver while
	/// `predicate` remains `true`.
	public func takeWhile(predicate: T -> Bool) -> HotSignal {
		return HotSignal { sink in
			let selfDisposable = SerialDisposable()

			selfDisposable.innerDisposable = self.observe { value in
				if predicate(value) {
					sink.put(value)
				} else {
					selfDisposable.dispose()
				}
			}
		}
	}

	/// Returns a signal that will skip the first `count` values from the
	/// receiver, then forward everything afterward.
	public func skip(count: Int) -> HotSignal {
		if (count == 0) {
			return self
		}

		let soFar = Atomic(0)

		return skipWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	/// Returns a signal that will skip values from the receiver while
	/// `predicate` remains `true`, then forward everything afterward.
	public func skipWhile(predicate: T -> Bool) -> HotSignal {
		let skipping = Atomic(true)

		return filter { value in
			if skipping.value {
				if predicate(value) {
					return false
				}

				skipping.value = false
			}

			return true
		}
	}

	/// Preserves only the values of the stream that pass the given predicate.
	public func filter(predicate: T -> Bool) -> HotSignal {
		return HotSignal { sink in
			self.observe { value in
				if predicate(value) {
					sink.put(value)
				}
			}

			return ()
		}
	}
}

/// Methods for combining multiple signals.
extension HotSignal {
	/// Merges a signal of signals down into a single signal, biased toward the
	/// signals added earlier.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward changes from the original signals
	/// as they arrive, starting with earlier ones.
	public func merge<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {
		return HotSignal<U> { sink in
			let signals = Atomic<[HotSignal<U>]>([])

			evidence(self).observe { signal in
				signals.modify { (var arr) in
					arr.append(signal)
					return arr
				}

				signal.observe(sink)
			}
		}
	}

	/// Switches on a signal of signals, forwarding values from the
	/// latest inner signal.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward changes only from the latest
	/// signal sent upon the receiver.
	public func switchToLatest<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {
		return HotSignal<U> { sink in
			let latestDisposable = SerialDisposable()

			evidence(self).observe { signal in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = signal.observe(sink)
			}
		}
	}
}

/// Blocking methods for receiving values.
extension HotSignal {
	/// Observes the receiver, then returns the first value received.
	public func next() -> T {
		let semaphore = dispatch_semaphore_create(0)
		var result: T?

		take(1).observe { value in
			result = value
			dispatch_semaphore_signal(semaphore)
		}

		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
		return result!
	}
}

/// Conversions from HotSignal to ColdSignal.
extension HotSignal {
	/// Buffers `count` values, starting at the time of the method invocation.
	///
	/// Returns a signal that will send the first `count` values observed on
	/// the receiver, then complete. If fewer than `count` values are observed,
	/// the returned signal will not complete, so it must be disposed manually.
	public func buffer(_ count: Int = 1) -> ColdSignal<T> {
		precondition(count >= 0)

		if count == 0 {
			return .empty()
		}

		let bufferProperty = ObservableProperty<[T]>([])

		let disposable = SerialDisposable()
		disposable.innerDisposable = observe { elem in
			var array = bufferProperty.value
			array.append(elem)

			if array.count == count {
				disposable.dispose()
			}

			bufferProperty.value = array
		}

		return bufferProperty.values()
			.mapAccumulate(0) { (lastIndex, values) in
				let newIndex = values.count - 1
				let signal = ColdSignal.fromValues(values[lastIndex...newIndex])
				return (newIndex, signal)
			}
			// FIXME: This should actually be concat(), which doesn't exist yet.
			.merge(identity)
			.take(count)
	}

	/// Replays up to `capacity` values, then forwards all future values.
	///
	/// Returns a signal that will forward the latest `capacity` (or fewer)
	/// values observed up to that point, then forward all future values from
	/// the receiver. The returned signal will never complete, so it must be
	/// disposed manually.
	public func replay(_ capacity: Int = 1) -> ColdSignal<T> {
		precondition(capacity >= 0)

		if capacity == 0 {
			return ColdSignal { subscriber in
				let disposable = self.observe { subscriber.put(.Next(Box($0))) }
				subscriber.disposable.addDisposable(disposable)
			}
		}

		let replayProperty = ObservableProperty<[(Int, T)]>([])
		var index = 0

		// TODO: Tear down this observation when the resulting ColdSignal
		// disappears somehow? Or maybe this will actually get taken care of by
		// the Signal lifetime.
		observe { elem in
			var array: [(Int, T)] = replayProperty.value
			let newEntry = (index++, elem)
			array.append(newEntry)

			if array.count > capacity {
				array.removeAtIndex(0)
			}

			replayProperty.value = array
		}

		return replayProperty.values()
			.mapAccumulate(0) { (var lastIndex, values) in
				var valuesToSend: [T] = []

				for (index, value) in values {
					if (index <= lastIndex) {
						continue
					}

					valuesToSend.append(value)
					lastIndex = index
				}

				return (lastIndex, ColdSignal.fromValues(valuesToSend))
			}
			// FIXME: This should actually be concat(), which doesn't exist yet.
			.merge(identity)
	}
}
