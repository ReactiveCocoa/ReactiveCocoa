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
	private let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.HotSignal", DISPATCH_QUEUE_CONCURRENT)
	private var observers = Bag<SinkOf<T>>()
	private var disposable: Disposable?

	/// Initializes a signal that will immediately perform the given action to
	/// begin generating its values.
	public init(_ generator: SinkOf<T> -> Disposable?) {
		// Weakly capture `self` so that lifetime is determined by any
		// observers, not the generator.
		disposable = generator(SinkOf { [weak self] value in
			if let strongSelf = self {
				dispatch_sync(strongSelf.queue) {
					for sink in strongSelf.observers {
						sink.put(value)
					}
				}
			}
		})
	}

	deinit {
		disposable?.dispose()
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
		return HotSignal { _ in nil }
	}

	/// Creates a signal that can be controlled by sending values to the
	/// returned sink.
	public class func pipe() -> (HotSignal, SinkOf<T>) {
		var sink: SinkOf<T>? = nil
		let signal = HotSignal { s in
			sink = s
			return nil
		}

		return (signal, sink!)
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
		precondition(interval >= 0)
		precondition(leeway >= 0)

		let startDate = scheduler.currentDate

		return HotSignal<NSDate> { sink in
			return scheduler.scheduleAfter(startDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: leeway) {
				sink.put(scheduler.currentDate)
			}
		}
	}
}

/// Transformative operators.
extension HotSignal {
	/// Maps each value in the stream to a new value.
	public func map<U>(f: T -> U) -> HotSignal<U> {
		return HotSignal<U> { sink in
			return self.observe { sink.put(f($0)) }
		}
	}

	/// Preserves only the values of the stream that pass the given predicate.
	public func filter(predicate: T -> Bool) -> HotSignal {
		return HotSignal { sink in
			return self.observe { value in
				if predicate(value) {
					sink.put(value)
				}
			}
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

	/// Returns a signal that will skip the first `count` values from the
	/// receiver, then forward everything afterward.
	public func skip(count: Int) -> HotSignal {
		precondition(count >= 0)

		if (count == 0) {
			return self
		}

		let soFar = Atomic(0)

		return skipWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	/// Skips all consecutive, repeating values in the signal, forwarding only
	/// the first occurrence.
	///
	/// evidence - Used to prove to the typechecker that the receiver contains
	///            values which are `Equatable`. Simply pass in the `identity`
	///            function.
	public func skipRepeats<U: Equatable>(evidence: HotSignal -> HotSignal<U>) -> HotSignal<U> {
		let previous = Atomic<U?>(nil)

		return evidence(self).filter { value in
			let previousValue = previous.value
			previous.value = value

			if let previousValue = previousValue {
				if value == previousValue {
					return false
				}
			}

			return true
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

	/// Returns a signal that will yield the first `count` values from the
	/// receiver.
	public func take(count: Int) -> HotSignal {
		precondition(count >= 0)

		if (count == 0) {
			return .never()
		}

		let soFar = Atomic(0)

		return takeWhile { _ in
			let orig = soFar.modify { $0 + 1 }
			return orig < count
		}
	}

	/// Forwards values from the receiver until `trigger` fires, at which point
	/// no further values will be sent.
	public func takeUntil(trigger: HotSignal<()>) -> HotSignal {
		let disposable = CompositeDisposable()
		let triggerDisposable = trigger.observe { _ in
			disposable.dispose()
		}

		disposable.addDisposable(triggerDisposable)

		return HotSignal { sink in
			let selfDisposable = self.observe(sink)
			disposable.addDisposable(selfDisposable)

			return disposable
		}
	}

	/// Forwards values from the receiver until `replacement` sends a value,
	/// at which point only values from `replacement` will be forwarded.
	public func takeUntilReplacement(replacement: HotSignal) -> HotSignal {
		return HotSignal { sink in
			let selfDisposable = self.observe(sink)
			let replacementDisposable = replacement.observe { value in
				selfDisposable.dispose()
				sink.put(value)
			}

			return CompositeDisposable([ selfDisposable, replacementDisposable ])
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

			return selfDisposable
		}
	}

	/// Forwards all values on the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func deliverOn(scheduler: Scheduler) -> HotSignal {
		return HotSignal { sink in
			return self.observe { value in
				scheduler.schedule { sink.put(value) }
				return ()
			}
		}
	}

	/// Delays values by the given interval, forwarding them on the given
	/// scheduler.
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> HotSignal {
		precondition(interval >= 0)

		return HotSignal { sink in
			return self.observe { value in
				let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
				scheduler.scheduleAfter(date) {
					sink.put(value)
				}
			}
		}
	}

	/// Throttle values sent by the receiver, so that at least `interval`
	/// seconds pass between each, then forwards them on the given scheduler.
	///
	/// If multiple values are received before the interval has elapsed, the
	/// latest value is the one that will be passed on.
	public func throttle(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> HotSignal {
		precondition(interval >= 0)

		let previousDate = Atomic<NSDate?>(nil)
		let disposable = SerialDisposable()

		return HotSignal { sink in
			return self.observe { value in
				disposable.innerDisposable = nil

				let now = scheduler.currentDate
				let (_, scheduleDate) = previousDate.modify { date -> (NSDate?, NSDate) in
					if date == nil || now.timeIntervalSinceDate(date!) >= interval {
						return (now, now)
					} else {
						return (date, date!.dateByAddingTimeInterval(interval))
					}
				}

				disposable.innerDisposable = scheduler.scheduleAfter(scheduleDate) { sink.put(value) }
			}
		}
	}

	/// Forwards the latest value from the receiver whenever `sampler` fires.
	///
	/// If `sampler` fires before a value has been observed on the receiver,
	/// nothing happens.
	public func sampleOn(sampler: HotSignal<()>) -> HotSignal {
		let latest = Atomic<T?>(nil)
		let selfDisposable = observe { latest.value = $0 }

		return HotSignal { sink in
			let samplerDisposable = sampler.observe { _ in
				if let value = latest.value {
					sink.put(value)
				}
			}

			return CompositeDisposable([ selfDisposable, samplerDisposable ])
		}
	}
}

/// Methods for combining multiple signals.
extension HotSignal {
	/// Combines the latest value of the receiver with the latest value from
	/// the given signal.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each.
	public func combineLatestWith<U>(signal: HotSignal<U>) -> HotSignal<(T, U)> {
		return HotSignal<(T, U)> { sink in
			let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.HotSignal.combineLatestWith", DISPATCH_QUEUE_SERIAL)
			var selfLatest: T? = nil
			var otherLatest: U? = nil

			let selfDisposable = self.observe { value in
				dispatch_sync(queue) {
					selfLatest = value
					if let otherLatest = otherLatest {
						sink.put((value, otherLatest))
					}
				}
			}

			let otherDisposable = signal.observe { value in
				dispatch_sync(queue) {
					otherLatest = value
					if let selfLatest = selfLatest {
						sink.put((selfLatest, value))
					}
				}
			}

			return CompositeDisposable([ selfDisposable, otherDisposable ])
		}
	}

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
			let disposable = CompositeDisposable()

			let selfDisposable = evidence(self).observe { signal in
				let innerDisposable = signal.observe(sink)
				disposable.addDisposable(innerDisposable)
			}

			disposable.addDisposable(selfDisposable)
			return disposable
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

			let selfDisposable = evidence(self).observe { signal in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = signal.observe(sink)
			}

			return CompositeDisposable([ selfDisposable, latestDisposable ])
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
			.mapAccumulate(initialState: 0) { (lastIndex, values) in
				let newIndex = values.count - 1
				let signal = ColdSignal.fromValues(values[lastIndex...newIndex])
				return (newIndex, signal)
			}
			.concat(identity)
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

		let selfDisposable = observe { elem in
			var array: [(Int, T)] = replayProperty.value
			let newEntry = (index++, elem)
			array.append(newEntry)

			if array.count > capacity {
				array.removeAtIndex(0)
			}

			replayProperty.value = array
		}

		let scopedDisposable = ScopedDisposable(selfDisposable)

		return replayProperty.values()
			.mapAccumulate(initialState: 0) { (var lastIndex, values) in
				var valuesToSend: [T] = []

				for (index, value) in values {
					if scopedDisposable.disposed {
						// This will never actually be true, but we want to keep
						// the disposable alive for at least as long as the
						// ColdSignal is.
						break
					}

					if (index <= lastIndex) {
						continue
					}

					valuesToSend.append(value)
					lastIndex = index
				}

				return (lastIndex, ColdSignal.fromValues(valuesToSend))
			}
			.concat(identity)
	}
}
