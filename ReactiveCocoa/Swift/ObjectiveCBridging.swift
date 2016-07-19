//
//  ObjectiveCBridging.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Result

extension RACDisposable: Disposable {}
extension RACScheduler: DateSchedulerProtocol {
	/// The current date, as determined by this scheduler.
	public var currentDate: Date {
		return Date()
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
	@discardableResult
	public func schedule(_ action: () -> Void) -> Disposable? {
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
	@discardableResult
	public func schedule(after date: Date, action: () -> Void) -> Disposable? {
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
	@discardableResult
	public func schedule(after date: Date, interval: TimeInterval, leeway: TimeInterval, action: () -> Void) -> Disposable? {
		return self.after(date, repeatingEvery: interval, withLeeway: leeway, schedule: action)
	}
}

extension ImmediateScheduler {
	/// Create `RACScheduler` that performs actions instantly.
	///
	/// - returns: `RACScheduler` that instantly performs actions.
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.immediate()
	}
}

extension UIScheduler {
	/// Create `RACScheduler` for `UIScheduler`
	///
	/// - returns: `RACScheduler` instance that queues events on main thread.
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.mainThread()
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

private func defaultNSError(_ message: String, file: String, line: Int) -> NSError {
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

extension SignalProducerProtocol where Value: AnyObject {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.lift { $0.optionalize() }
			.toRACSignal()
	}
}

extension SignalProducerProtocol where Value: OptionalProtocol, Value.Wrapped: AnyObject {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.mapError { $0 as NSError }
			.toRACSignal()
	}
}

extension SignalProducerProtocol where Value: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.lift { $0.optionalize() }
			.toRACSignal()
	}
}

extension SignalProducerProtocol where Value: OptionalProtocol, Value.Wrapped: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will `start()` the producer once for each
	/// subscription.
	///
	/// - note: Any `interrupted` events will be silently discarded.
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
				case let .next(value):
					subscriber.sendNext(value.optional)
				case let .failed(error):
					subscriber.sendError(error)
				case .completed:
					subscriber.sendCompleted()
				case .interrupted:
					break
				}
			}

			return RACDisposable {
				selfDisposable.dispose()
			}
		}
	}
}

extension SignalProtocol where Value: AnyObject {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.optionalize()
			.toRACSignal()
	}
}

extension SignalProtocol where Value: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.optionalize()
			.toRACSignal()
	}
}

extension SignalProtocol where Value: OptionalProtocol, Value.Wrapped: AnyObject {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - returns: `RACSignal` instantiated from `self`.
	public func toRACSignal() -> RACSignal {
		return self
			.mapError { $0 as NSError }
			.toRACSignal()
	}
}

extension SignalProtocol where Value: OptionalProtocol, Value.Wrapped: AnyObject, Error: NSError {
	/// Create a `RACSignal` that will observe the given signal.
	///
	/// - note: Any `interrupted` events will be silently discarded.
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
				case let .next(value):
					subscriber.sendNext(value.optional)
				case let .failed(error):
					subscriber.sendError(error)
				case .completed:
					subscriber.sendCompleted()
				case .interrupted:
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

// FIXME: Reintroduce `RACCommand.toAction` when compiler no longer segfault
//        on extensions to parameterized ObjC classes.
/**
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
**/

extension ActionProtocol {
	private var isCommandEnabled: RACSignal {
		return self.isEnabled.producer
			.map { $0 as NSNumber }
			.toRACSignal()
	}
}

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
public func bridgedAction<Input>(from command: RACCommand<Input>, file: String = #file, line: Int = #line) -> Action<AnyObject?, AnyObject?, NSError> {
	let command = command as! RACCommand<AnyObject>
	let enabledProperty = MutableProperty(true)

	enabledProperty <~ command.enabled.toSignalProducer()
		.map { $0 as! Bool }
		.flatMapError { _ in SignalProducer<Bool, NoError>(value: false) }

	return Action(enabledIf: enabledProperty) { input -> SignalProducer<AnyObject?, NSError> in
		let executionSignal = RACSignal.`defer` {
			return command.execute(input)
		}

		return executionSignal.toSignalProducer(file: file, line: line)
	}
}

extension ActionProtocol where Input: AnyObject, Output: AnyObject {
	/// Creates a RACCommand that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the RACCommand is.
	///
	/// - returns: `RACCommand` with bound action.
	public func toRACCommand() -> RACCommand<Input> {
		return RACCommand<Input>(enabled: action.isCommandEnabled) { input -> RACSignal in
			return self
				.apply(input!)
				.toRACSignal()
		}
	}
}

extension ActionProtocol where Input: OptionalProtocol, Input.Wrapped: AnyObject, Output: AnyObject {
	/// Creates a RACCommand that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the RACCommand is.
	///
	/// - returns: `RACCommand` with bound action.
	public func toRACCommand() -> RACCommand<Input.Wrapped> {
		return RACCommand<Input.Wrapped>(enabled: action.isCommandEnabled) { input -> RACSignal in
			return self
				.apply(Input(reconstructing: input))
				.toRACSignal()
		}
	}
}

extension ActionProtocol where Input: AnyObject, Output: OptionalProtocol, Output.Wrapped: AnyObject {
	/// Creates a RACCommand that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the RACCommand is.
	///
	/// - returns: `RACCommand` with bound action.
	public func toRACCommand() -> RACCommand<Input> {
		return RACCommand<Input>(enabled: action.isCommandEnabled) { input -> RACSignal in
			return self
				.apply(input!)
				.toRACSignal()
		}
	}
}

extension ActionProtocol where Input: OptionalProtocol, Input.Wrapped: AnyObject, Output: OptionalProtocol, Output.Wrapped: AnyObject {
	/// Creates a RACCommand that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the RACCommand is.
	///
	/// - returns: `RACCommand` with bound action.
	public func toRACCommand() -> RACCommand<Input.Wrapped> {
		return RACCommand<Input.Wrapped>(enabled: action.isCommandEnabled) { input -> RACSignal in
			return self
				.apply(Input(reconstructing: input))
				.toRACSignal()
		}
	}
}
