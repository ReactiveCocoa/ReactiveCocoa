//
//  HotSignal.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-25.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

/// A push-driven stream that sends the same values to all observers.
///
/// Generally, hot signals do not need to be retained in order to observe the
/// values they send, but there are some exceptions. See the documentation for
/// observe() and HotSignal.weak() for more information.
public final class HotSignal<T> {
	private let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.HotSignal", DISPATCH_QUEUE_CONCURRENT)
	private var observers: Bag<SinkOf<T>>? = Bag()
	private var disposable: Disposable?

	/// The file in which this signal was defined, if known.
	internal let file: String?

	/// The function in which this signal was defined, if known.
	internal let function: String?

	/// The line number upon which this signal was defined, if known.
	internal let line: Int?

	/// Initializes a HotSignal, then starts it by invoking the given generator.
	private init(file: String, line: Int, function: String, generator: HotSignal -> Disposable?) {
		self.file = file
		self.line = line
		self.function = function

		disposable = generator(self)
	}

	/// Initializes a HotSignal that will terminate naturally.
	///
	/// HotSignals initialized this way will stay alive as long as their
	/// generator maintains a reference to the passed-in sink. observe() can be
	/// invoked upon a HotSignal initialized this way without retaining the
	/// signal itself or the returned disposable.
	///
	/// HotSignals initialized this way cannot be terminated before their work
	/// has finished.
	///
	/// If you need early termination, or automatic deallocation when all
	/// references are lost, see HotSignal.weak().
	public convenience init(_ generator: SinkOf<T> -> (), file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		self.init(file: file, line: line, function: function, generator: { signal in
			let disposable = ScopedDisposable(ActionDisposable {
				signal.close()
			})

			generator(SinkOf { value in
				signal.put(value)

				// Ensures that `scopedDisposable` will be deallocated when this
				// block goes away, thereby removing all observers from the
				// signal.
				if disposable.disposed {}
			})

			return nil
		})
	}

	deinit {
		disposable?.dispose()
	}

	/// Sends the given value to all observers.
	private func put(value: T) {
		dispatch_sync(self.queue) {
			if let observers = self.observers {
				for sink in observers {
					sink.put(value)
				}
			}
		}
	}

	/// Removes all observers, and prevents any new observers from attaching.
	private func close() {
		dispatch_barrier_async(self.queue) {
			self.observers = nil
		}
	}

	/// Notifies `observer` about new values from the receiver.
	///
	/// If this signal was created through HotSignal.weak, you must keep a
	/// strong reference to the HotSignal or the returned Disposable in order to
	/// keep receiving values.
	///
	/// Otherwise (if the signal was initialized with HotSignal.init), your
	/// observer will be retained until the signal has finished generating
	/// values, or until the returned Disposable is explicitly disposed.
	///
	/// Returns a Disposable which can be disposed of to stop notifying
	/// `observer` of future changes.
	public func observe<S: SinkType where S.Element == T>(observer: S) -> Disposable {
		let sink = SinkOf<T>(observer)
		var token: RemovalToken? = nil

		dispatch_barrier_sync(queue) {
			token = self.observers?.insert(sink)
		}

		return ActionDisposable {
			if let token = token {
				// Retain `self` strongly so that observers can hold onto the signal
				// _or_ the disposable to ensure the receipt of values.
				dispatch_barrier_async(self.queue) {
					self.observers?.removeValueForToken(token)
					return
				}
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
	/// Creates a “weak” HotSignal, which will automatically terminate when all
	/// references to it are lost.
	///
	/// In order to observe a weak signal without it disappearing, the
	/// disposable returned from observe() or the HotSignal itself must be
	/// retained for the duration of the observation.
	public class func weak(generator: SinkOf<T> -> Disposable?, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) -> HotSignal {
		return HotSignal(file: file, line: line, function: function) { signal in
			return generator(SinkOf { [weak signal] value in
				signal?.put(value)
				return
			})
		}
	}

	/// Creates a signal that will never send any values.
	public class func never() -> HotSignal {
		return HotSignal.weak { _ in nil }
	}

	/// Creates a signal that can be controlled by sending values to the
	/// returned sink.
	///
	/// The signal will be kept alive for as long as the sink is, ensuring that
	/// values sent to the sink will be properly forwarded to observers even if
	/// a direct reference to the signal is lost.
	public class func pipe() -> (HotSignal, SinkOf<T>) {
		var sink: SinkOf<T>? = nil
		let signal = HotSignal { sink = $0 }

		return (signal, sink!)
	}

	/// Creates a repeating timer of the given interval, with a reasonable
	/// default leeway, sending updates on the given scheduler.
	///
	/// The timer will automatically be destroyed when there are no more strong
	/// references to the returned signal, and no Disposables returned from
	/// observe() are still around.
	public class func interval(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> HotSignal<NSDate> {
		// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
		// at least 10% of the timer interval.
		return self.interval(interval, onScheduler: scheduler, withLeeway: interval * 0.1)
	}

	/// Creates a repeating timer of the given interval, sending updates on the
	/// given scheduler.
	///
	/// The timer will automatically be destroyed when there are no more strong
	/// references to the returned signal, and no Disposables returned from
	/// observe() are still around.
	public class func interval(interval: NSTimeInterval, onScheduler scheduler: DateScheduler, withLeeway leeway: NSTimeInterval) -> HotSignal<NSDate> {
		precondition(interval >= 0)
		precondition(leeway >= 0)

		let startDate = scheduler.currentDate

		return HotSignal<NSDate>.weak { sink in
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
			self.observe { value in
				sink.put(f(value))
			}

			return
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

			return
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
		return evidence(self).skipRepeats { $0 == $1 }
	}

	/// Skips all consecutive, repeating values in the signal, forwarding only
	/// the first occurrence.
	///
	/// isEqual - Used to determine whether two values are equal. The `==`
	///           function will work in most cases.
	public func skipRepeats(isEqual: (T, T) -> Bool) -> HotSignal<T> {
		let previous = Atomic<T?>(nil)

		return filter { value in
			let previousValue = previous.value
			previous.value = value

			if let previousValue = previousValue {
				if isEqual(value, previousValue) {
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

		if count == 0 {
			return .never()
		}

		let soFar = Atomic(0)
		let selfDisposable = SerialDisposable()

		return HotSignal { sink in
			selfDisposable.innerDisposable = self.observe { value in
				sink.put(value)

				let orig = soFar.modify { $0 + 1 }
				if orig + 1 >= count {
					selfDisposable.dispose()
				}
			}
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
			disposable.addDisposable(self.observe(sink))
			return
		}
	}

	/// Forwards values from the receiver until `replacement` sends a value,
	/// at which point only values from `replacement` will be forwarded.
	public func takeUntilReplacement(replacement: HotSignal) -> HotSignal {
		return HotSignal { sink in
			let selfDisposable = self.observe(sink)
			replacement.observe { value in
				selfDisposable.dispose()
				sink.put(value)
			}

			return
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

	/// Forwards all values on the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	public func deliverOn(scheduler: Scheduler) -> HotSignal {
		return HotSignal { sink in
			self.observe { value in
				scheduler.schedule { sink.put(value) }
				return
			}

			return
		}
	}

	/// Delays values by the given interval, forwarding them on the given
	/// scheduler.
	public func delay(interval: NSTimeInterval, onScheduler scheduler: DateScheduler) -> HotSignal {
		precondition(interval >= 0)

		return HotSignal { sink in
			self.observe { value in
				let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
				scheduler.scheduleAfter(date) {
					sink.put(value)
				}
			}

			return
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
			self.observe { value in
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

			return
		}
	}

	/// Forwards the latest value from the receiver whenever `sampler` fires.
	///
	/// If `sampler` fires before a value has been observed on the receiver,
	/// nothing happens.
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	public func sampleOn(sampler: HotSignal<()>) -> HotSignal {
		let latest = Atomic<T?>(nil)
		let selfDisposable = observe { latest.value = $0 }

		return HotSignal.weak { sink in
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
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	///
	/// The returned signal will not send a value until both inputs have sent
	/// at least one value each.
	public func combineLatestWith<U>(signal: HotSignal<U>) -> HotSignal<(T, U)> {
		return HotSignal<(T, U)>.weak { sink in
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

	/// Zips elements of two signals into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input signals.
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	public func zipWith<U>(signal: HotSignal<U>) -> HotSignal<(T, U)> {
		return HotSignal<(T, U)>.weak { sink in
			let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.HotSignal.zipWith", DISPATCH_QUEUE_SERIAL)
			var selfValues: [T] = []
			var otherValues: [U] = []

			let flushValues: () -> () = {
				while !selfValues.isEmpty && !otherValues.isEmpty {
					let pair = (selfValues[0], otherValues[0])
					selfValues.removeAtIndex(0)
					otherValues.removeAtIndex(0)

					sink.put(pair)
				}
			}

			let selfDisposable = self.observe { value in
				dispatch_sync(queue) {
					selfValues.append(value)
					flushValues()
				}
			}

			let otherDisposable = signal.observe { value in
				dispatch_sync(queue) {
					otherValues.append(value)
					flushValues()
				}
			}

			return CompositeDisposable([ selfDisposable, otherDisposable ])
		}
	}

	/// Merges a HotSignal of HotSignals down into a single HotSignal, biased toward the
	/// signals added earlier.
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a HotSignal that will forward changes from the original signals
	/// as they arrive, starting with earlier ones.
	public func merge<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {
		return HotSignal<U>.weak { sink in
			let disposable = CompositeDisposable()

			let selfDisposable = evidence(self).observe { signal in
				let innerDisposable = signal.observe(sink)
				disposable.addDisposable(innerDisposable)
			}

			disposable.addDisposable(selfDisposable)
			return disposable
		}
	}

	/// Merges a SequenceType of HotSignals down into a single HotSignal, biased toward the
	/// signals appearing earlier in the sequence.
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	///
	/// Returns a HotSignal that will forward changes from the original signals
	/// in the sequence, starting with earlier ones.
	public class func merge<S: SequenceType where S.Generator.Element == HotSignal<T>>(signals: S) -> HotSignal<T> {
		let (signal, sink) = HotSignal<HotSignal<T>>.pipe()
		let merged = signal.merge(identity)
		var generator = signals.generate()
		while let signal: HotSignal<T> = generator.next() {
			sink.put(signal)
		}
		return merged
	}
	
	/// Maps each value that the receiver sends to a new signal, then merges the
	/// resulting signals together.
	///
	/// This is equivalent to map() followed by merge().
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	///
	/// Returns a signal that will forward changes from all mapped signals as
	/// they arrive.
	public func mergeMap<U>(f: T -> HotSignal<U>) -> HotSignal<U> {
		return map(f).merge(identity)
	}

	/// Switches on a signal of signals, forwarding values from the
	/// latest inner signal.
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of signals. Simply pass in the `identity` function.
	///
	/// Returns a signal that will forward changes only from the latest
	/// signal sent upon the receiver.
	public func switchToLatest<U>(evidence: HotSignal -> HotSignal<HotSignal<U>>) -> HotSignal<U> {
		return HotSignal<U>.weak { sink in
			let latestDisposable = SerialDisposable()

			let selfDisposable = evidence(self).observe { signal in
				latestDisposable.innerDisposable = nil
				latestDisposable.innerDisposable = signal.observe(sink)
			}

			return CompositeDisposable([ selfDisposable, latestDisposable ])
		}
	}

	/// Maps each value that the receiver sends to a new signal, then forwards
	/// the values sent by the latest mapped signal.
	///
	/// This is equivalent to map() followed by switchToLatest().
	///
	/// The returned signal will automatically be destroyed when there are no
	/// more strong references to it, and no Disposables returned from observe()
	/// are still around.
	///
	/// Returns a signal that will forward changes only from the latest mapped
	/// signal to arrive.
	public func switchMap<U>(f: T -> HotSignal<U>) -> HotSignal<U> {
		return map(f).switchToLatest(identity)
	}
}

/// Blocking methods for receiving values.
extension HotSignal {
	/// Observes the receiver, then returns the first value received.
	public func next() -> T {
		let semaphore = dispatch_semaphore_create(0)
		var result: T?

		let disposable = take(1).observe { value in
			result = value
			dispatch_semaphore_signal(semaphore)
		}

		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

		// The signal is actually already disposed by this point, but keeping
		// this disposable ensures that the signal is not deallocated while we
		// wait for a value.
		disposable.dispose()

		return result!
	}
}

/// An overloaded function that combines the values of up to 10 signals, in the
/// manner described by HotSignal.combineLatestWith().
public func combineLatest<A, B>(a: HotSignal<A>, b: HotSignal<B>) -> HotSignal<(A, B)> {
	return a.combineLatestWith(b)
}

public func combineLatest<A, B, C>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>) -> HotSignal<(A, B, C)> {
	return combineLatest(a, b)
		.combineLatestWith(c)
		.map(repack)
}

public func combineLatest<A, B, C, D>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>) -> HotSignal<(A, B, C, D)> {
	return combineLatest(a, b, c)
		.combineLatestWith(d)
		.map(repack)
}

public func combineLatest<A, B, C, D, E>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>) -> HotSignal<(A, B, C, D, E)> {
	return combineLatest(a, b, c, d)
		.combineLatestWith(e)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>) -> HotSignal<(A, B, C, D, E, F)> {
	return combineLatest(a, b, c, d, e)
		.combineLatestWith(f)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>) -> HotSignal<(A, B, C, D, E, F, G)> {
	return combineLatest(a, b, c, d, e, f)
		.combineLatestWith(g)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G, H>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>, h: HotSignal<H>) -> HotSignal<(A, B, C, D, E, F, G, H)> {
	return combineLatest(a, b, c, d, e, f, g)
		.combineLatestWith(h)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G, H, I>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>, h: HotSignal<H>, i: HotSignal<I>) -> HotSignal<(A, B, C, D, E, F, G, H, I)> {
	return combineLatest(a, b, c, d, e, f, g, h)
		.combineLatestWith(i)
		.map(repack)
}

public func combineLatest<A, B, C, D, E, F, G, H, I, J>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>, h: HotSignal<H>, i: HotSignal<I>, j: HotSignal<J>) -> HotSignal<(A, B, C, D, E, F, G, H, I, J)> {
	return combineLatest(a, b, c, d, e, f, g, h, i)
		.combineLatestWith(j)
		.map(repack)
}

/// An overloaded function that zips the values of up to 10 signals, in the
/// manner described by HotSignal.zipWith().
public func zip<A, B>(a: HotSignal<A>, b: HotSignal<B>) -> HotSignal<(A, B)> {
	return a.zipWith(b)
}

public func zip<A, B, C>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>) -> HotSignal<(A, B, C)> {
	return zip(a, b)
		.zipWith(c)
		.map(repack)
}

public func zip<A, B, C, D>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>) -> HotSignal<(A, B, C, D)> {
	return zip(a, b, c)
		.zipWith(d)
		.map(repack)
}

public func zip<A, B, C, D, E>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>) -> HotSignal<(A, B, C, D, E)> {
	return zip(a, b, c, d)
		.zipWith(e)
		.map(repack)
}

public func zip<A, B, C, D, E, F>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>) -> HotSignal<(A, B, C, D, E, F)> {
	return zip(a, b, c, d, e)
		.zipWith(f)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>) -> HotSignal<(A, B, C, D, E, F, G)> {
	return zip(a, b, c, d, e, f)
		.zipWith(g)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G, H>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>, h: HotSignal<H>) -> HotSignal<(A, B, C, D, E, F, G, H)> {
	return zip(a, b, c, d, e, f, g)
		.zipWith(h)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G, H, I>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>, h: HotSignal<H>, i: HotSignal<I>) -> HotSignal<(A, B, C, D, E, F, G, H, I)> {
	return zip(a, b, c, d, e, f, g, h)
		.zipWith(i)
		.map(repack)
}

public func zip<A, B, C, D, E, F, G, H, I, J>(a: HotSignal<A>, b: HotSignal<B>, c: HotSignal<C>, d: HotSignal<D>, e: HotSignal<E>, f: HotSignal<F>, g: HotSignal<G>, h: HotSignal<H>, i: HotSignal<I>, j: HotSignal<J>) -> HotSignal<(A, B, C, D, E, F, G, H, I, J)> {
	return zip(a, b, c, d, e, f, g, h, i)
		.zipWith(j)
		.map(repack)
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
		let disposable = take(count).observe { elem in
			bufferProperty.value.append(elem)
		}

		return bufferProperty.values
			.mapAccumulate(initialState: 0) { (startIndex, values) in
				// This disposable will never actually be disposed here, but we
				// want to use it to keep the property and observation alive for
				// as long as the ColdSignal is.
				if disposable.disposed {
					bufferProperty.value = []
				}

				if values.count > startIndex {
					let newIndex = values.count
					let slice = values[startIndex ..< newIndex]
					return (newIndex, ColdSignal.fromValues(slice))
				} else {
					return (startIndex, ColdSignal.empty())
				}
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
			return ColdSignal { (sink, disposable) in
				let selfDisposable = self.observe { sendNext(sink, $0) }
				disposable.addDisposable(selfDisposable)
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

		return replayProperty.values
			.mapAccumulate(initialState: -1) { (var lastIndex, values) in
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

/// Debugging utilities.
extension HotSignal {
	/// Logs every value that passes through the signal.
	///
	/// Returns the receiver, for easy chaining.
	public func log() -> HotSignal {
		observe { [unowned self] value in
			debugPrintln("\(self.debugDescription): \(value)")
		}

		return self
	}
}

extension HotSignal: DebugPrintable {
	public var debugDescription: String {
		let function = self.function ?? ""
		let file = self.file ?? ""
		let line = self.line?.description ?? ""

		return "\(function).HotSignal (\(file):\(line))"
	}
}
