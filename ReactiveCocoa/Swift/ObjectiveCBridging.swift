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
	public var currentDate: NSDate {
		return NSDate()
	}

	public func schedule(action: () -> ()) -> Disposable? {
		let disposable: RACDisposable = self.schedule(action) // Call the Objective-C implementation
		return disposable as Disposable?
	}

	public func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		return self.after(date, schedule: action)
	}

	public func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		return self.after(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, schedule: action)
	}
}

extension ImmediateScheduler {
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.immediateScheduler()
	}
}

extension UIScheduler {
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.mainThreadScheduler()
	}
}

extension QueueScheduler {
	public func toRACScheduler() -> RACScheduler {
		return RACTargetQueueScheduler(name: "org.reactivecocoa.ReactiveCocoa.QueueScheduler.toRACScheduler()", targetQueue: queue)
	}
}

private func defaultNSError(message: String, file: String, line: Int) -> NSError {
	return Result<(), NSError>.error(message, file: file, line: line)
}

extension RACSignal {
	/// Creates a SignalProducer which will subscribe to the receiver once for
	/// each invocation of start().
	public func toSignalProducer(file: String = __FILE__, line: Int = __LINE__) -> SignalProducer<AnyObject?, NSError> {
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
	/// Turns each value into an Optional.
	private func optionalize() -> Signal<Value?, Error> {
		return signal.map(Optional.init)
	}
}

/// Creates a RACSignal that will start() the producer once for each
/// subscription.
///
/// Any `Interrupted` events will be silently discarded.
public func toRACSignal<Value: AnyObject, Error>(producer: SignalProducer<Value, Error>) -> RACSignal {
	return toRACSignal(producer.lift { $0.optionalize() })
}

/// Creates a RACSignal that will start() the producer once for each
/// subscription.
///
/// Any `Interrupted` events will be silently discarded.
public func toRACSignal<Value: AnyObject, Error: NSError>(producer: SignalProducer<Value, Error>) -> RACSignal {
	return toRACSignal(producer.lift { $0.optionalize() })
}

/// Creates a RACSignal that will start() the producer once for each
/// subscription.
///
/// Any `Interrupted` events will be silently discarded.
public func toRACSignal<Value: AnyObject, Error>(producer: SignalProducer<Value?, Error>) -> RACSignal {
    return toRACSignal(producer.mapError { $0 as NSError })
}

/// Creates a RACSignal that will start() the producer once for each
/// subscription.
///
/// Any `Interrupted` events will be silently discarded.
public func toRACSignal<Value: AnyObject, Error: NSError>(producer: SignalProducer<Value?, Error>) -> RACSignal {
    // This special casing of `Error: NSError` is a workaround for rdar://22708537
    // which causes an NSError's UserInfo dictionary to get discarded
    // during a cast from ErrorType to NSError in a generic function
	return RACSignal.createSignal { subscriber in
		let selfDisposable = producer.start { event in
			switch event {
			case let .Next(value):
				subscriber.sendNext(value)
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

/// Creates a RACSignal that will observe the given signal.
///
/// Any `Interrupted` event will be silently discarded.
public func toRACSignal<Value: AnyObject, Error>(signal: Signal<Value, Error>) -> RACSignal {
	return toRACSignal(signal.optionalize())
}

/// Creates a RACSignal that will observe the given signal.
///
/// Any `Interrupted` event will be silently discarded.
public func toRACSignal<Value: AnyObject, Error: NSError>(signal: Signal<Value, Error>) -> RACSignal {
	return toRACSignal(signal.optionalize())
}

/// Creates a RACSignal that will observe the given signal.
///
/// Any `Interrupted` event will be silently discarded.
public func toRACSignal<Value: AnyObject, Error>(signal: Signal<Value?, Error>) -> RACSignal {
    return toRACSignal(signal.mapError { $0 as NSError })
}

/// Creates a RACSignal that will observe the given signal.
///
/// Any `Interrupted` event will be silently discarded.
public func toRACSignal<Value: AnyObject, Error: NSError>(signal: Signal<Value?, Error>) -> RACSignal {
    // This special casing of `Error: NSError` is a workaround for rdar://22708537
    // which causes an NSError's UserInfo dictionary to get discarded
    // during a cast from ErrorType to NSError in a generic function
    return RACSignal.createSignal { subscriber in
        let selfDisposable = signal.observe { event in
            switch event {
            case let .Next(value):
                subscriber.sendNext(value)
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

extension RACCommand {
	/// Creates an Action that will execute the receiver.
	///
	/// Note that the returned Action will not necessarily be marked as
	/// executing when the command is. However, the reverse is always true:
	/// the RACCommand will always be marked as executing when the action is.
	public func toAction(file: String = __FILE__, line: Int = __LINE__) -> Action<AnyObject?, AnyObject?, NSError> {
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

extension Action {
	private var commandEnabled: RACSignal {
		let enabled = self.enabled.producer.map { $0 as NSNumber }
		return toRACSignal(enabled)
	}
}

/// Creates a RACCommand that will execute the action.
///
/// Note that the returned command will not necessarily be marked as
/// executing when the action is. However, the reverse is always true:
/// the Action will always be marked as executing when the RACCommand is.
public func toRACCommand<Output: AnyObject, Error>(action: Action<AnyObject?, Output, Error>) -> RACCommand {
	return RACCommand(enabled: action.commandEnabled) { input -> RACSignal in
		return toRACSignal(action.apply(input))
	}
}

/// Creates a RACCommand that will execute the action.
///
/// Note that the returned command will not necessarily be marked as
/// executing when the action is. However, the reverse is always true:
/// the Action will always be marked as executing when the RACCommand is.
public func toRACCommand<Output: AnyObject, Error>(action: Action<AnyObject?, Output?, Error>) -> RACCommand {
	return RACCommand(enabled: action.commandEnabled) { input -> RACSignal in
		return toRACSignal(action.apply(input))
	}
}
