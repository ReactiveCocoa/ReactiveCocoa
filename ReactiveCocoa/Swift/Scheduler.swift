//
//  Scheduler.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Represents a serial queue of work items.
public protocol SchedulerType {
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
public protocol DateSchedulerType: SchedulerType {
	/// The current date, as determined by this scheduler.
	///
	/// This can be implemented to deterministic return a known date (e.g., for
	/// testing purposes).
	var currentDate: NSDate { get }

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
public final class ImmediateScheduler: SchedulerType {
	public init() {}

	public func schedule(action: () -> ()) -> Disposable? {
		action()
		return nil
	}
}

/// A scheduler that performs all work on the main thread, as soon as possible.
///
/// If the caller is already running on the main thread when an action is
/// scheduled, it may be run synchronously. However, ordering between actions
/// will always be preserved.
public final class UIScheduler: SchedulerType {
	private var queueLength: Int32 = 0

	public init() {}

	public func schedule(action: () -> ()) -> Disposable? {
		let disposable = SimpleDisposable()
		let actionAndDecrement: () -> () = {
			if !disposable.disposed {
				action()
			}

			withUnsafeMutablePointer(&self.queueLength, OSAtomicDecrement32)
		}

		let queued = withUnsafeMutablePointer(&queueLength, OSAtomicIncrement32)

		// If we're already running on the main thread, and there isn't work
		// already enqueued, we can skip scheduling and just execute directly.
		if NSThread.isMainThread() && queued == 1 {
			actionAndDecrement()
		} else {
			dispatch_async(dispatch_get_main_queue(), actionAndDecrement)
		}

		return disposable
	}
}

/// A scheduler backed by a serial GCD queue.
public final class QueueScheduler: DateSchedulerType {
	internal let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.QueueScheduler", DISPATCH_QUEUE_SERIAL)

	/// A singleton QueueScheduler that always targets the main thread's GCD
	/// queue.
	///
	/// Unlike UIScheduler, this scheduler supports scheduling for a future
	/// date, and will always schedule asynchronously (even if already running
	/// on the main thread).
	public static let mainQueueScheduler = QueueScheduler(dispatch_get_main_queue())

	public var currentDate: NSDate {
		return NSDate()
	}

	/// Initializes a scheduler that will target the given queue with its work.
	///
	/// Even if the queue is concurrent, all work items enqueued with the
	/// QueueScheduler will be serial with respect to each other.
	public init(_ queue: dispatch_queue_t) {
		dispatch_set_target_queue(self.queue, queue)
	}

	/// Initializes a scheduler that will target the global queue with the given
	/// priority.
	public convenience init(_ priority: CLong) {
		self.init(dispatch_get_global_queue(priority, 0))
	}

	/// Initializes a scheduler that will target the default priority global
	/// queue.
	public convenience init() {
		self.init(DISPATCH_QUEUE_PRIORITY_DEFAULT)
	}

	public func schedule(action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()

		dispatch_async(queue) {
			if !d.disposed {
				action()
			}
		}

		return d
	}

	private func wallTimeWithDate(date: NSDate) -> dispatch_time_t {
		var seconds = 0.0
		let frac = modf(date.timeIntervalSince1970, &seconds)

		let nsec: Double = frac * Double(NSEC_PER_SEC)
		var walltime = timespec(tv_sec: CLong(seconds), tv_nsec: CLong(nsec))

		return dispatch_walltime(&walltime, 0)
	}

	public func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()

		dispatch_after(wallTimeWithDate(date), queue) {
			if !d.disposed {
				action()
			}
		}

		return d
	}

	/// Schedules a recurring action at the given interval, beginning at the
	/// given start time, and with a reasonable default leeway.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	public func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, action: () -> ()) -> Disposable? {
		// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
		// at least 10% of the timer interval.
		return scheduleAfter(date, repeatingEvery: repeatingEvery, withLeeway: repeatingEvery * 0.1, action: action)
	}

	public func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway leeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		precondition(repeatingEvery >= 0)
		precondition(leeway >= 0)

		let nsecInterval = repeatingEvery * Double(NSEC_PER_SEC)
		let nsecLeeway = leeway * Double(NSEC_PER_SEC)

		let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
		dispatch_source_set_timer(timer, wallTimeWithDate(date), UInt64(nsecInterval), UInt64(nsecLeeway))
		dispatch_source_set_event_handler(timer, action)
		dispatch_resume(timer)

		return ActionDisposable {
			dispatch_source_cancel(timer)
		}
	}
}

/// A scheduler that implements virtualized time, for use in testing.
public final class TestScheduler: DateSchedulerType {
	private final class ScheduledAction {
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

	private let lock = NSRecursiveLock()
	private var _currentDate: NSDate

	/// The virtual date that the scheduler is currently at.
	public var currentDate: NSDate {
		let d: NSDate

		lock.lock()
		d = _currentDate
		lock.unlock()

		return d
	}

	private var scheduledActions: [ScheduledAction] = []

	/// Initializes a TestScheduler with the given start date.
	public init(startDate: NSDate = NSDate(timeIntervalSinceReferenceDate: 0)) {
		lock.name = "org.reactivecocoa.ReactiveCocoa.TestScheduler"
		_currentDate = startDate
	}

	private func schedule(action: ScheduledAction) -> Disposable {
		lock.lock()
		scheduledActions.append(action)
		scheduledActions.sort { $0.less($1) }
		lock.unlock()

		return ActionDisposable {
			self.lock.lock()
			self.scheduledActions = self.scheduledActions.filter { $0 !== action }
			self.lock.unlock()
		}
	}

	public func schedule(action: () -> ()) -> Disposable? {
		return schedule(ScheduledAction(date: currentDate, action: action))
	}

	/// Schedules an action for execution at or after the given interval
	/// (counted from `currentDate`).
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	public func scheduleAfter(interval: NSTimeInterval, action: () -> ()) -> Disposable? {
		return scheduleAfter(currentDate.dateByAddingTimeInterval(interval), action: action)
	}

	public func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		return schedule(ScheduledAction(date: date, action: action))
	}

	private func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, disposable: SerialDisposable, action: () -> ()) {
		precondition(repeatingEvery >= 0)

		disposable.innerDisposable = scheduleAfter(date) { [unowned self] in
			action()
			self.scheduleAfter(date.dateByAddingTimeInterval(repeatingEvery), repeatingEvery: repeatingEvery, disposable: disposable, action: action)
		}
	}

	/// Schedules a recurring action at the given interval, beginning at the
	/// given interval (counted from `currentDate`).
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	public func scheduleAfter(interval: NSTimeInterval, repeatingEvery: NSTimeInterval, withLeeway leeway: NSTimeInterval = 0, action: () -> ()) -> Disposable? {
		return scheduleAfter(currentDate.dateByAddingTimeInterval(interval), repeatingEvery: repeatingEvery, withLeeway: leeway, action: action)
	}

	public func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval = 0, action: () -> ()) -> Disposable? {
		let disposable = SerialDisposable()
		scheduleAfter(date, repeatingEvery: repeatingEvery, disposable: disposable, action: action)
		return disposable
	}

	/// Advances the virtualized clock by an extremely tiny interval, dequeuing
	/// and executing any actions along the way.
	///
	/// This is intended to be used as a way to execute actions that have been
	/// scheduled to run as soon as possible.
	public func advance() {
		advanceByInterval(DBL_EPSILON)
	}

	/// Advances the virtualized clock by the given interval, dequeuing and
	/// executing any actions along the way.
	public func advanceByInterval(interval: NSTimeInterval) {
		lock.lock()
		advanceToDate(currentDate.dateByAddingTimeInterval(interval))
		lock.unlock()
	}

	/// Advances the virtualized clock to the given future date, dequeuing and
	/// executing any actions up until that point.
	public func advanceToDate(newDate: NSDate) {
		lock.lock()

		assert(currentDate.compare(newDate) != NSComparisonResult.OrderedDescending)
		_currentDate = newDate

		while scheduledActions.count > 0 {
			if newDate.compare(scheduledActions[0].date) == NSComparisonResult.OrderedAscending {
				break
			}

			let scheduledAction = scheduledActions[0]
			scheduledActions.removeAtIndex(0)
			scheduledAction.action()
		}

		lock.unlock()
	}

	/// Dequeues and executes all scheduled actions, leaving the scheduler's
	/// date at `NSDate.distantFuture()`.
	public func run() {
		advanceToDate(NSDate.distantFuture() as! NSDate)
	}
}
