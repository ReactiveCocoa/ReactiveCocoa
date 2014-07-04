//
//  Scheduler.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a serial queue of work items.
protocol Scheduler {
	/// Enqueues an action on the scheduler.
	///
	/// When the work is executed depends on the scheduler in use.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func schedule(action: () -> ()) -> Disposable?

	/// Schedules an action for execution at or after the given date.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable?
}

/// A particular kind of scheduler that supports repeating actions.
protocol RepeatableScheduler: Scheduler {
	/// Schedules a recurring action at the given interval, beginning at the
	/// given start time.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable?
}

/// Represents a scheduler that can be bridged to Objective-C RAC code.
protocol BridgedScheduler {
	func asRACScheduler() -> RACScheduler
}

// Purposely matches RACScheduler.m, so we can bridge the currentScheduler
// across the two.
let currentSchedulerKey = "RACSchedulerCurrentSchedulerKey"

/// Returns the scheduler upon which the calling code is executing, if any.
var currentScheduler: protocol<Scheduler, BridgedScheduler>? {
	get {
		return NSThread.currentThread().threadDictionary[currentSchedulerKey] as? RACScheduler
	}
}

/// Performs an action while setting `currentScheduler` to the given
/// scheduler instance.
func _asCurrentScheduler<T>(scheduler: protocol<Scheduler, BridgedScheduler>, action: () -> T) -> T {
	let previousScheduler: AnyObject? = NSThread.currentThread().threadDictionary[currentSchedulerKey]

	NSThread.currentThread().threadDictionary[currentSchedulerKey] = scheduler.asRACScheduler()
	let result = action()
	NSThread.currentThread().threadDictionary[currentSchedulerKey] = previousScheduler

	return result
}

/// A scheduler that performs all work synchronously.
struct ImmediateScheduler: Scheduler {
	func schedule(action: () -> ()) -> Disposable? {
		action()
		return nil
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		NSThread.sleepUntilDate(date)
		return schedule(action)
	}
}

/// A scheduler that performs all work on the main thread.
struct MainScheduler: RepeatableScheduler {
	let _innerScheduler = QueueScheduler(dispatch_get_main_queue())

	func schedule(action: () -> ()) -> Disposable? {
		return _innerScheduler.schedule(action)
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		return _innerScheduler.scheduleAfter(date, action: action)
	}

	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		return _innerScheduler.scheduleAfter(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, action: action)
	}
}

/// A scheduler backed by a serial GCD queue.
struct QueueScheduler: Scheduler {
	let _queue = dispatch_queue_create("com.github.ReactiveCocoa.QueueScheduler", DISPATCH_QUEUE_SERIAL)

	/// Initializes a scheduler that will target the given queue with its work.
	///
	/// Even if the queue is concurrent, all work items enqueued with the
	/// QueueScheduler will be serial with respect to each other.
	init(_ queue: dispatch_queue_t) {
		dispatch_set_target_queue(_queue, queue)
	}
	
	/// Initializes a scheduler that will target the global queue with the given
	/// priority.
	init(_ priority: CLong) {
		self.init(dispatch_get_global_queue(priority, 0))
	}
	
	/// Initializes a scheduler that will target the default priority global
	/// queue.
	init() {
		self.init(DISPATCH_QUEUE_PRIORITY_DEFAULT)
	}
	
	func schedule(action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()
	
		dispatch_async(_queue, {
			if d.disposed {
				return
			}
			
			_asCurrentScheduler(self, action)
		})
		
		return d
	}

	func _wallTimeWithDate(date: NSDate) -> dispatch_time_t {
		var seconds = 0.0
		let frac = modf(date.timeIntervalSince1970, &seconds)
		
		let nsec: Double = frac * Double(NSEC_PER_SEC)
		var walltime = timespec(tv_sec: CLong(seconds), tv_nsec: CLong(nsec))
		
		return dispatch_walltime(&walltime, 0)
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()

		dispatch_after(_wallTimeWithDate(date), _queue, {
			if d.disposed {
				return
			}

			_asCurrentScheduler(self, action)
		})

		return d
	}

	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway leeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		let nsecInterval = repeatingEvery * Double(NSEC_PER_SEC)
		let nsecLeeway = leeway * Double(NSEC_PER_SEC)
		
		let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue)
		dispatch_source_set_timer(timer, _wallTimeWithDate(date), UInt64(nsecInterval), UInt64(nsecLeeway))
		dispatch_source_set_event_handler(timer, action)
		dispatch_resume(timer)

		return ActionDisposable {
			dispatch_source_cancel(timer)
		}
	}
}

/// A scheduler that will attempt to use any `currentScheduler` that exists at
/// the time of scheduling.
struct DeferredCurrentScheduler: Scheduler {
	/// The scheduler to use if no `currentScheduler` is set when an action is
	/// enqueued.
	let fallbackScheduler: Scheduler

	func schedule(action: () -> ()) -> Disposable? {
		if let s = currentScheduler {
			return s.schedule(action)
		} else {
			return fallbackScheduler.schedule(action)
		}
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		if let s = currentScheduler {
			return s.scheduleAfter(date, action)
		} else {
			return fallbackScheduler.scheduleAfter(date, action)
		}
	}
}
