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
	public var currentDate: Date {
		return Date()
	}

	public func schedule(_ action: () -> Void) -> Disposable? {
		let disposable: RACDisposable = self.schedule(action) // Call the Objective-C implementation
		return disposable as Disposable?
	}

	public func scheduleAfter(_ date: Date, action: () -> Void) -> Disposable? {
		return self.after(date, schedule: action)
	}

	public func scheduleAfter(_ date: Date, repeatingEvery: TimeInterval, withLeeway: TimeInterval, action: () -> Void) -> Disposable? {
		return self.after(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, schedule: action)
	}
}

extension ImmediateScheduler {
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.immediate()
	}
}

extension UIScheduler {
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.mainThread()
	}
}

extension QueueScheduler {
	public func toRACScheduler() -> RACScheduler {
		return RACTargetQueueScheduler(name: "org.reactivecocoa.ReactiveCocoa.QueueScheduler.toRACScheduler()", targetQueue: queue)
	}
}

private func defaultNSError(_ message: String, file: String, line: Int) -> NSError {
	return Result<(), NSError>.error(message, file: file, line: line)
}

extension RACSignal {
	/// Creates a SignalProducer which will subscribe to the receiver once for
	/// each invocation of start().
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

extension SignalProtocol {
	/// Turns each value into an Optional.
	private func optionalize() -> Signal<Value?, Error> {
		return signal.map(Optional.init)
	}
}

// MARK: - toRACSignal

extension SignalProducerProtocol where Value: AnyObject {
	/// Creates a RACSignal that will start() the producer once for each
	/// subscription.
	///
	/// Any `Interrupted` events will be silently discarded.
	public func toRACSignal() -> RACSignal {
		return self
			.lift { $0.optionalize() }
			.toRACSignal()
	}
}

extension SignalProducerProtocol where Value: OptionalType, Value.Wrapped: AnyObject {
	/// Creates a RACSignal that will start() the producer once for each
	/// subscription.
	///
	/// Any `Interrupted` events will be silently discarded.
	public func toRACSignal() -> RACSignal {
		return self
			.mapError { $0 as NSError }
			.toRACSignal()
	}
}

extension SignalProducerProtocol where Value: AnyObject, Error: NSError {
	/// Creates a RACSignal that will start() the producer once for each
	/// subscription.
	///
	/// Any `Interrupted` events will be silently discarded.
	public func toRACSignal() -> RACSignal {
		return self
			.lift { $0.optionalize() }
			.toRACSignal()
	}
}

extension SignalProducerProtocol where Value: OptionalType, Value.Wrapped: AnyObject, Error: NSError {
	/// Creates a RACSignal that will start() the producer once for each
	/// subscription.
	///
	/// Any `Interrupted` events will be silently discarded.
	public func toRACSignal() -> RACSignal {
		// This special casing of `Error: NSError` is a workaround for rdar://22708537
		// which causes an NSError's UserInfo dictionary to get discarded
		// during a cast from ErrorType to NSError in a generic function
		return RACSignal.createSignal { subscriber in
			let selfDisposable = self.start { event in
				switch event {
				case let .next(value):
					subscriber!.sendNext(value.optional)
				case let .failed(error):
					subscriber!.sendError(error)
				case .completed:
					subscriber?.sendCompleted()
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
	/// Creates a RACSignal that will observe the given signal.
	///
	/// Any `Interrupted` event will be silently discarded.
	public func toRACSignal() -> RACSignal {
		return self
			.optionalize()
			.toRACSignal()
	}
}

extension SignalProtocol where Value: AnyObject, Error: NSError {
	/// Creates a RACSignal that will observe the given signal.
	///
	/// Any `Interrupted` event will be silently discarded.
	public func toRACSignal() -> RACSignal {
		return self
			.optionalize()
			.toRACSignal()
	}
}

extension SignalProtocol where Value: OptionalType, Value.Wrapped: AnyObject {
	/// Creates a RACSignal that will observe the given signal.
	///
	/// Any `Interrupted` event will be silently discarded.
	public func toRACSignal() -> RACSignal {
		return self
			.mapError { $0 as NSError }
			.toRACSignal()
	}
}

extension SignalProtocol where Value: OptionalType, Value.Wrapped: AnyObject, Error: NSError {
	/// Creates a RACSignal that will observe the given signal.
	///
	/// Any `Interrupted` event will be silently discarded.
	public func toRACSignal() -> RACSignal {
		// This special casing of `Error: NSError` is a workaround for rdar://22708537
		// which causes an NSError's UserInfo dictionary to get discarded
		// during a cast from ErrorType to NSError in a generic function
		return RACSignal.createSignal { subscriber in
			let selfDisposable = self.observe { event in
				switch event {
				case let .next(value):
					subscriber!.sendNext(value.optional)
				case let .failed(error):
					subscriber!.sendError(error)
				case .completed:
					subscriber?.sendCompleted()
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

extension ActionProtocol {
	private var commandEnabled: RACSignal {
		return self.enabled.producer
			.map { $0 as NSNumber }
			.toRACSignal()
	}
}

/// Creates an Action that will execute the receiver.
///
/// Note that the returned Action will not necessarily be marked as
/// executing when the command is. However, the reverse is always true:
/// the RACCommand will always be marked as executing when the action is.
public func toAction<Input>(command: RACCommand<Input>, file: String = #file, line: Int = #line) -> Action<AnyObject?, AnyObject?, NSError> {
	let command = command as! RACCommand<AnyObject>
	let enabledProperty = MutableProperty(true)

	enabledProperty <~ command.enabled.toSignalProducer()
		.map { $0 as! Bool }
		.flatMapError { _ in SignalProducer<Bool, NoError>(value: false) }

	return Action(enabledIf: enabledProperty) { input -> SignalProducer<AnyObject?, NSError> in
		let executionSignal = RACSignal.`defer` {
			return command.execute(input)
		}

		return executionSignal!.toSignalProducer(file: file, line: line)
	}
}

/// Creates a RACCommand that will execute the action.
///
/// Note that the returned command will not necessarily be marked as
/// executing when the action is. However, the reverse is always true:
/// the Action will always be marked as executing when the RACCommand is.
public func toRACCommand<Output: AnyObject, Error>(_ action: Action<AnyObject?, Output, Error>) -> RACCommand<AnyObject> {
	return RACCommand(enabled: action.commandEnabled) { input -> RACSignal in
		return action
			.apply(input)
			.toRACSignal()
	}
}

/// Creates a RACCommand that will execute the action.
///
/// Note that the returned command will not necessarily be marked as
/// executing when the action is. However, the reverse is always true:
/// the Action will always be marked as executing when the RACCommand is.
public func toRACCommand<Output: AnyObject, Error>(_ action: Action<AnyObject?, Output?, Error>) -> RACCommand<AnyObject> {
	return RACCommand(enabled: action.commandEnabled) { input -> RACSignal in
		return action
			.apply(input)
			.toRACSignal()
	}
}
