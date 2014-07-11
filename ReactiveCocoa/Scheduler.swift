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
}

/// A particular kind of scheduler that supports enqueuing actions at future
/// dates.
protocol DateScheduler: Scheduler {
	/// Schedules an action for execution at or after the given date.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable?

	/// Schedules a recurring action at the given interval, beginning at the
	/// given start time.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable?
}

/// A scheduler that performs all work synchronously.
struct ImmediateScheduler: Scheduler {
	func schedule(action: () -> ()) -> Disposable? {
		action()
		return nil
	}
}

/// A scheduler that performs all work on the main thread.
struct MainScheduler: DateScheduler {
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
struct QueueScheduler: DateScheduler {
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
			
			action()
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

			action()
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

/// A scheduler that implements virtualized time, for use in testing.
@final class TestScheduler: DateScheduler {
	@final class ScheduledAction {
		let date: NSDate
		let action: () -> ()

		init(date: NSDate, action: () -> ()) {
			self.date = date
			self.action = action
		}

		func less(rhs: ScheduledAction) -> Bool {
			return date.compare(rhs.date) == NSComparisonResult.OrderedAscending
		}
	}

	let _lock = NSRecursiveLock()
	var _currentDate: NSDate

	/// The virtual date that the scheduler is currently at.
	var currentDate: NSDate {
		get {
			var d: NSDate? = nil

			_lock.lock()
			d = self._currentDate
			_lock.unlock()

			return d!
		}
	}

	var _scheduledActions: [ScheduledAction] = []

	/// Initializes a TestScheduler with the given start date.
	init(startDate: NSDate = NSDate(timeIntervalSinceReferenceDate: 0)) {
		_lock.name = "com.github.ReactiveCocoa.TestScheduler"
		_currentDate = startDate
	}

	func schedule(action: ScheduledAction) -> Disposable {
		_lock.lock()
		_scheduledActions.append(action)
		_scheduledActions.sort { $0.less($1) }
		_lock.unlock()

		return ActionDisposable {
			self._lock.lock()
			self._scheduledActions = self._scheduledActions.filter { $0 !== action }
			self._lock.unlock()
		}
	}

	func schedule(action: () -> ()) -> Disposable? {
		return schedule(ScheduledAction(date: currentDate, action: action))
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		return schedule(ScheduledAction(date: date, action: action))
	}

	func _scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, disposable: SerialDisposable, action: () -> ()) {
		disposable.innerDisposable = scheduleAfter(date) { [unowned self] in
			action()
			self._scheduleAfter(date.dateByAddingTimeInterval(repeatingEvery), repeatingEvery: repeatingEvery, disposable: disposable, action: action)
		}
	}

	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		let disposable = SerialDisposable()
		_scheduleAfter(date, repeatingEvery: repeatingEvery, disposable: disposable, action: action)
		return disposable
	}

	/// Advances the virtualized clock by the given interval, dequeuing and
	/// executing any actions along the way.
	func advanceByInterval(interval: NSTimeInterval) {
		_lock.lock()
		advanceToDate(currentDate.dateByAddingTimeInterval(interval))
		_lock.unlock()
	}

	/// Advances the virtualized clock to the given future date, dequeuing and
	/// executing any actions up until that point.
	func advanceToDate(newDate: NSDate) {
		_lock.lock()

		assert(currentDate.compare(newDate) != NSComparisonResult.OrderedDescending)
		_currentDate = newDate
			
		while _scheduledActions.count > 0 {
			if newDate.compare(_scheduledActions[0].date) == NSComparisonResult.OrderedAscending {
				break
			}

			let scheduledAction = _scheduledActions[0]
			_scheduledActions.removeAtIndex(0)
			scheduledAction.action()
		}

		_lock.unlock()
	}

	/// Dequeues and executes all scheduled actions, leaving the scheduler's
	/// date at `NSDate.distantFuture()`.
	func run() {
		advanceToDate(NSDate.distantFuture() as NSDate)
	}
}
