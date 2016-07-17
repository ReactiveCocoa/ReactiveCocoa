//
//  ObjectiveCBridging.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Result

extension RACDisposable: Disposable {}

extension RACScheduler: DateSchedulerType {
	/// The current date, as determined by this scheduler.
	public var currentDate: NSDate {
		return NSDate()
	}

	/// Schedule an action for immediate execution.
	///
	/// - note: This method calls the Objective-C implementation of `schedule:`
	///         method.
	///
	/// - parameters:
	///   - action: Closure to perform.
	///
	/// - returns: Disposable that can be used to cancel the work before it
	///            begins.
	public func schedule(action: () -> Void) -> Disposable? {
		let disposable: RACDisposable = self.schedule(action) // Call the Objective-C implementation
		return disposable as Disposable?
	}

	/// Schedule an action for execution at or after the given date.
	///
	/// - parameters:
	///   - date: Starting date.
	///   - action: Closure to perform.
	///
	/// - returns: Optional disposable that can be used to cancel the work
	///            before it begins.
	public func scheduleAfter(date: NSDate, action: () -> Void) -> Disposable? {
		return self.after(date, schedule: action)
	}

	/// Schedule a recurring action at the given interval, beginning at the
	/// given start time.
	///
	/// - parameters:
	///   - date: Starting date.
	///   - repeatingEvery: Repetition interval.
	///   - withLeeway: Some delta for repetition.
	///   - action: Closure of the action to perform.
	///
	/// - returns: Optional `Disposable` that can be used to cancel the work
	///            before it begins.
	public func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> Void) -> Disposable? {
		return self.after(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, schedule: action)
	}
}

extension ImmediateScheduler {
	/// Create `RACScheduler` that performs actions instantly.
	///
	/// - returns: `RACScheduler` that instantly performs actions.
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.immediateScheduler()
	}
}

extension UIScheduler {
	/// Create `RACScheduler` for `UIScheduler`
	///
	/// - returns: `RACScheduler` instance that queues events on main thread.
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.mainThreadScheduler()
	}
}

extension QueueScheduler {
	/// Create `RACScheduler` backed with own queue
	///
	/// - returns: Instance `RACScheduler` that queues events on
	///            `QueueScheduler`'s queue.
	public func toRACScheduler() -> RACScheduler {
		return RACTargetQueueScheduler(name: "org.reactivecocoa.ReactiveCocoa.QueueScheduler.toRACScheduler()", targetQueue: queue)
	}
}

private func defaultNSError(message: String, file: String, line: Int) -> NSError {
	return Result<(), NSError>.error(message, file: file, line: line)
}

extension RACSignal {
	/// Create a `SignalProducer` which will subscribe to the receiver once for
	/// each invocation of `start()`.
	///
	/// - parameters:
	///   - file: Current file name.
	///   - line: Current line in file.
	///
	/// - returns: Signal producer created from `self`.
	public func toSignalProducer(file: String = #file, line: Int = #line) -> SignalProducer<AnyObject?, NSError> {
		return SignalProducer { observer, disposable in
			let next = { obj in
				observer.sendNext(obj)
			}

			let failed = { nsError in
				observer.sendFailed(nsError ?? defaultNSError("Nil RACSignal error", file: file, line: line))
			}

			let completed = {
				observer.sendCompleted()
			}

			disposable += self.subscribeNext(next, error: failed, completed: completed)
		}
	}
}

extension SignalType {
	/// Turn each value into an Optional.
	private func optionalize() -> Signal<Value?, Error> {
		return signal.map(Optional.init)
	}
}

// MARK: - toRACSignal

extension SignalProducerType where Value: AnyObject {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.lift { $0.optionalize() }
			.toRACSignal()
	}
}

extension SignalProducerType where Value: OptionalType, Value.Wrapped: AnyObject {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.mapError { $0 as NSError }
			.toRACSignal()
	}
}

extension SignalProducerType where Value: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.lift { $0.optionalize() }
			.toRACSignal()
	}
}

extension SignalProducerType where Value: OptionalType, Value.Wrapped: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		// This special casing of `Error: NSError` is a workaround for
		// rdar://22708537 which causes an NSError's UserInfo dictionary to get
		// discarded during a cast from ErrorType to NSError in a generic
		// function
		return RACSignal.createSignal { subscriber in
			let selfDisposable = self.start { event in
				switch event {
				case let .Next(value):
					subscriber.sendNext(value.optional)
				case let .Failed(error):
					subscriber.sendError(error)
				case .Completed:
					subscriber.sendCompleted()
				case .Interrupted:
					break
				}
			}

			return RACDisposable {
				selfDisposable.dispose()
			}
		}
	}
}

extension SignalType where Value: AnyObject {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.optionalize()
			.toRACSignal()
	}
}

extension SignalType where Value: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.optionalize()
			.toRACSignal()
	}
}

extension SignalType where Value: OptionalType, Value.Wrapped: AnyObject {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.mapError { $0 as NSError }
			.toRACSignal()
	}
}

extension SignalType where Value: OptionalType, Value.Wrapped: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `Interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		// This special casing of `Error: NSError` is a workaround for
		// rdar://22708537 which causes an NSError's UserInfo dictionary to get
		// discarded during a cast from ErrorType to NSError in a generic
		// function
		return RACSignal.createSignal { subscriber in
			let selfDisposable = self.observe { event in
				switch event {
				case let .Next(value):
					subscriber.sendNext(value.optional)
				case let .Failed(error):
					subscriber.sendError(error)
				case .Completed:
					subscriber.sendCompleted()
				case .Interrupted:
					break
				}
			}

			return RACDisposable {
				selfDisposable?.dispose()
			}
		}
	}
}

// MARK: -

extension RACCommand {
	/// Creates an Action that will execute the receiver.
	///
	/// - note: The returned Action will not necessarily be marked as executing
	///         when the command is. However, the reverse is always true: the
	///         RACCommand will always be marked as executing when the action
	///         is.
	///
	/// - parameters:
	///   - file: Current file name.
	///   - line: Current line in file.
	///
	/// - returns: Action created from `self`.
	public func toAction(file: String = #file, line: Int = #line) -> Action<AnyObject?, AnyObject?, NSError> {
		let enabledProperty = MutableProperty(true)

		enabledProperty <~ self.enabled.toSignalProducer()
			.map { $0 as! Bool }
			.flatMapError { _ in SignalProducer<Bool, NoError>(value: false) }

		return Action(enabledIf: enabledProperty) { input -> SignalProducer<AnyObject?, NSError> in
			let executionSignal = RACSignal.`defer` {
				return self.execute(input)
			}

			return executionSignal.toSignalProducer(file, line: line)
		}
	}
}

extension ActionType {
	private var commandEnabled: RACSignal {
		return self.enabled.producer
			.map { $0 as NSNumber }
			.toRACSignal()
	}
}

/// Create a `RACCommand` that will execute the action.
///
/// - note: The returned command will not necessarily be marked as executing
///         when the action is. However, the reverse is always true: the Action
///         will always be marked as executing when the RACCommand is.
///
/// - returns: `RACCommand` with bound action.
public func toRACCommand<Output: AnyObject, Error>(action: Action<AnyObject?, Output, Error>) -> RACCommand {
	return RACCommand(enabled: action.commandEnabled) { input -> RACSignal in
		return action
			.apply(input)
			.toRACSignal()
	}
}

/// Creates a RACCommand that will execute the action.
///
/// - note: The returned command will not necessarily be marked as executing
///         when the action is. However, the reverse is always true: the Action
///         will always be marked as executing when the RACCommand is.
///
/// - returns: `RACCommand` with bound action.
public func toRACCommand<Output: AnyObject, Error>(action: Action<AnyObject?, Output?, Error>) -> RACCommand {
	return RACCommand(enabled: action.commandEnabled) { input -> RACSignal in
		return action
			.apply(input)
			.toRACSignal()
	}
}
