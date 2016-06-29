//
//  Scheduler.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a serial queue of work items.
public protocol SchedulerProtocol {
	/// Enqueues an action on the scheduler.
	///
	/// When the work is executed depends on the scheduler in use.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	@discardableResult
	func schedule(_ action: () -> Void) -> Disposable?
}

/// A particular kind of scheduler that supports enqueuing actions at future
/// dates.
public protocol DateSchedulerProtocol: SchedulerProtocol {
	/// The current date, as determined by this scheduler.
	///
	/// This can be implemented to deterministic return a known date (e.g., for
	/// testing purposes).
	var currentDate: Date { get }

	/// Schedules an action for execution at or after the given date.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	@discardableResult
	func scheduleAfter(_ date: Date, action: () -> Void) -> Disposable?

	/// Schedules a recurring action at the given interval, beginning at the
	/// given start time.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	@discardableResult
	func scheduleAfter(_ date: Date, repeatingEvery: TimeInterval, withLeeway: TimeInterval, action: () -> Void) -> Disposable?
}

/// A scheduler that performs all work synchronously.
public final class ImmediateScheduler: SchedulerProtocol {
	public init() {}

	@discardableResult
	public func schedule(_ action: () -> Void) -> Disposable? {
		action()
		return nil
	}
}

/// A scheduler that performs all work on the main queue, as soon as possible.
///
/// If the caller is already running on the main queue when an action is
/// scheduled, it may be run synchronously. However, ordering between actions
/// will always be preserved.
public final class UIScheduler: SchedulerProtocol {
	private static let dispatchSpecificKey = DispatchSpecificKey<UInt8>()
	private static var __once: () = {
			DispatchQueue.main.setSpecific(key: UIScheduler.dispatchSpecificKey,
			                               value: UInt8.max)
	}()

	private var queueLength: Int32 = 0

	public init() {
		/// This call is to ensure the main queue has been setup appropriately
		/// for `UIScheduler`. It is only called once during the application
		/// lifetime, since Swift has a `dispatch_once` like mechanism to
		/// lazily initialize global variables and static variables.
		_ = UIScheduler.__once
	}

	@discardableResult
	public func schedule(_ action: () -> Void) -> Disposable? {
		let disposable = SimpleDisposable()
		let actionAndDecrement = {
			if !disposable.disposed {
				action()
			}

			OSAtomicDecrement32(&self.queueLength)
		}

		let queued = OSAtomicIncrement32(&queueLength)

		// If we're already running on the main queue, and there isn't work
		// already enqueued, we can skip scheduling and just execute directly.
		if queued == 1 && DispatchQueue.getSpecific(key: UIScheduler.dispatchSpecificKey) == UInt8.max {
			actionAndDecrement()
		} else {
			DispatchQueue.main.async(execute: actionAndDecrement)
		}

		return disposable
	}
}

/// A scheduler backed by a serial GCD queue.
public final class QueueScheduler: DateSchedulerProtocol {
	internal let queue: DispatchQueue
	
	internal init(internalQueue: DispatchQueue) {
		queue = internalQueue
	}
	
	/// Initializes a scheduler that will target the given queue with its work.
	///
	/// Even if the queue is concurrent, all work items enqueued with the
	/// QueueScheduler will be serial with respect to each other.
	///
  	/// - warning: Obsoleted in OS X 10.11
	@available(OSX, deprecated:10.10, obsoleted:10.11, message:"Use init(qos:, name:) instead.")
	@available(iOS, deprecated:8.0, obsoleted:9.0, message:"Use init(qos:, name:) instead.")
	public convenience init(queue: DispatchQueue, name: String = "org.reactivecocoa.ReactiveCocoa.QueueScheduler") {
		self.init(internalQueue: DispatchQueue(label: name, attributes: DispatchQueueAttributes.serial))
		self.queue.setTarget(queue: queue)
	}

	/// A singleton QueueScheduler that always targets the main thread's GCD
	/// queue.
	///
	/// Unlike UIScheduler, this scheduler supports scheduling for a future
	/// date, and will always schedule asynchronously (even if already running
	/// on the main thread).
	public static let mainQueueScheduler = QueueScheduler(internalQueue: DispatchQueue.main)
	
	public var currentDate: Date {
		return Date()
	}

	/// Initializes a scheduler that will target a new serial
	/// queue with the given quality of service class.
	@available(iOS 8, watchOS 2, OSX 10.10, *)
	public convenience init(qos: DispatchQoS = .default, name: String = "org.reactivecocoa.ReactiveCocoa.QueueScheduler") {

		// TODO/FIXME [@liscio]: This seems really silly to have to implement in this manner, and I suspect that Dispatch either needs to be cleaned up to merge these concepts in some way, or we need to change the initialization API.
		//
		// In a nutshell, declaring the qos parameter as DispatchQueueAttributes would allow the caller to specify additional OptionSet values that get stashed into the queue attributes. Instead we just want to specify a specific QoS value which then gets translated into the attributes option flag.

		let qosAttribute: DispatchQueueAttributes
		switch qos {
		case DispatchQoS.userInteractive:
			qosAttribute = .qosUserInteractive
		case DispatchQoS.userInitiated:
			qosAttribute = .qosUserInitiated
		case DispatchQoS.background:
			qosAttribute = .qosBackground
		case DispatchQoS.utility:
			qosAttribute = .qosUtility
		default:
			qosAttribute = .qosDefault
		}

		self.init(internalQueue: DispatchQueue(label: name, attributes: [.serial, qosAttribute]))
	}

	@discardableResult
	public func schedule(_ action: () -> Void) -> Disposable? {
		let d = SimpleDisposable()

		queue.async {
			if !d.disposed {
				action()
			}
		}

		return d
	}

	private func wallTimeWithDate(_ date: Date) -> DispatchWallTime {

		let (seconds, frac) = modf(date.timeIntervalSince1970)

		let nsec: Double = frac * Double(NSEC_PER_SEC)
		let walltime = timespec(tv_sec: Int(seconds), tv_nsec: Int(nsec))

		return DispatchWallTime(time: walltime)
	}

	@discardableResult
	public func scheduleAfter(_ date: Date, action: () -> Void) -> Disposable? {
		let d = SimpleDisposable()

		queue.after(walltime: wallTimeWithDate(date)) {
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
	@discardableResult
	public func scheduleAfter(_ date: Date, repeatingEvery: TimeInterval, action: () -> Void) -> Disposable? {
		// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
		// at least 10% of the timer interval.
		return scheduleAfter(date, repeatingEvery: repeatingEvery, withLeeway: repeatingEvery * 0.1, action: action)
	}

	@discardableResult
	public func scheduleAfter(_ date: Date, repeatingEvery: TimeInterval, withLeeway leeway: TimeInterval, action: () -> Void) -> Disposable? {
		precondition(repeatingEvery >= 0)
		precondition(leeway >= 0)

		let nsecInterval = repeatingEvery * Double(NSEC_PER_SEC)
		let nsecLeeway = leeway * Double(NSEC_PER_SEC)

		let timer = DispatchSource.timer(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: queue)
		timer.scheduleRepeating(wallDeadline: wallTimeWithDate(date),
		                        interval: .nanoseconds(Int(nsecInterval)),
		                        leeway: .nanoseconds(Int(nsecLeeway)))
		timer.setEventHandler(handler: action)
		timer.resume()

		return ActionDisposable {
			timer.cancel()
		}
	}
}

/// A scheduler that implements virtualized time, for use in testing.
public final class TestScheduler: DateSchedulerProtocol {
	private final class ScheduledAction {
		let date: Date
		let action: () -> Void

		init(date: Date, action: () -> Void) {
			self.date = date
			self.action = action
		}

		func less(_ rhs: ScheduledAction) -> Bool {
			return date.compare(rhs.date) == .orderedAscending
		}
	}

	private let lock = RecursiveLock()
	private var _currentDate: Date

	/// The virtual date that the scheduler is currently at.
	public var currentDate: Date {
		let d: Date

		lock.lock()
		d = _currentDate
		lock.unlock()

		return d
	}

	private var scheduledActions: [ScheduledAction] = []

	/// Initializes a TestScheduler with the given start date.
	public init(startDate: Date = Date(timeIntervalSinceReferenceDate: 0)) {
		lock.name = "org.reactivecocoa.ReactiveCocoa.TestScheduler"
		_currentDate = startDate
	}

	private func schedule(_ action: ScheduledAction) -> Disposable {
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

	@discardableResult
	public func schedule(_ action: () -> Void) -> Disposable? {
		return schedule(ScheduledAction(date: currentDate, action: action))
	}

	/// Schedules an action for execution at or after the given interval
	/// (counted from `currentDate`).
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	@discardableResult
	public func scheduleAfter(_ interval: TimeInterval, action: () -> Void) -> Disposable? {
		return scheduleAfter(currentDate.addingTimeInterval(interval), action: action)
	}

	@discardableResult
	public func scheduleAfter(_ date: Date, action: () -> Void) -> Disposable? {
		return schedule(ScheduledAction(date: date, action: action))
	}

	private func scheduleAfter(_ date: Date, repeatingEvery: TimeInterval, disposable: SerialDisposable, action: () -> Void) {
		precondition(repeatingEvery >= 0)

		disposable.innerDisposable = scheduleAfter(date) { [unowned self] in
			action()
			self.scheduleAfter(date.addingTimeInterval(repeatingEvery), repeatingEvery: repeatingEvery, disposable: disposable, action: action)
		}
	}

	/// Schedules a recurring action at the given interval, beginning at the
	/// given interval (counted from `currentDate`).
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	@discardableResult
	public func scheduleAfter(_ interval: TimeInterval, repeatingEvery: TimeInterval, withLeeway leeway: TimeInterval = 0, action: () -> Void) -> Disposable? {
		return scheduleAfter(currentDate.addingTimeInterval(interval), repeatingEvery: repeatingEvery, withLeeway: leeway, action: action)
	}

	@discardableResult
	public func scheduleAfter(_ date: Date, repeatingEvery: TimeInterval, withLeeway: TimeInterval = 0, action: () -> Void) -> Disposable? {
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
	public func advanceByInterval(_ interval: TimeInterval) {
		lock.lock()
		advanceToDate(currentDate.addingTimeInterval(interval))
		lock.unlock()
	}

	/// Advances the virtualized clock to the given future date, dequeuing and
	/// executing any actions up until that point.
	public func advanceToDate(_ newDate: Date) {
		lock.lock()

		assert(currentDate.compare(newDate) != .orderedDescending)

		while scheduledActions.count > 0 {
			if newDate.compare(scheduledActions[0].date) == .orderedAscending {
				break
			}

			_currentDate = scheduledActions[0].date

			let scheduledAction = scheduledActions.remove(at: 0)
			scheduledAction.action()
		}

		_currentDate = newDate

		lock.unlock()
	}

	/// Dequeues and executes all scheduled actions, leaving the scheduler's
	/// date at `NSDate.distantFuture()`.
	public func run() {
		advanceToDate(Date.distantFuture)
	}
}
