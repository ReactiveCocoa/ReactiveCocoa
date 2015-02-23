//
//  ObjectiveCBridging.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import LlamaKit

extension RACDisposable: Disposable {}
extension RACScheduler: DateSchedulerType {
	public var currentDate: NSDate {
		return NSDate()
	}

	public func schedule(action: () -> ()) -> Disposable? {
		return self.schedule(action)
	}

	public func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		return self.after(date, schedule: action)
	}

	public func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		return self.after(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, schedule: action)
	}
}

extension ImmediateScheduler {
	public func asRACScheduler() -> RACScheduler {
		return RACScheduler.immediateScheduler()
	}
}

extension UIScheduler {
	public func asRACScheduler() -> RACScheduler {
		return RACScheduler.mainThreadScheduler()
	}
}

extension QueueScheduler {
	public func asRACScheduler() -> RACScheduler {
		return RACTargetQueueScheduler(name: "org.reactivecocoa.ReactiveCocoa.QueueScheduler.asRACScheduler()", targetQueue: queue)
	}
}

private func defaultNSError(message: String, #file: String, #line: Int) -> NSError {
	// lol hax
	let result: Result<(), NSError> = failure(message, file: file, line: line)
	return result.error!
}

extension RACSignal {
	/// Creates a SignalProducer which will subscribe to the receiver once for
	/// each invocation of start().
	public func asSignalProducer(file: String = __FILE__, line: Int = __LINE__) -> SignalProducer<AnyObject?, NSError> {
		return SignalProducer { observer, disposable in
			let next = { (obj: AnyObject?) -> () in
				sendNext(observer, obj)
			}

			let error = { (nsError: NSError?) -> () in
				sendError(observer, nsError ?? defaultNSError("Nil RACSignal error", file: file, line: line))
			}

			let completed = {
				sendCompleted(observer)
			}

			let selfDisposable: RACDisposable? = self.subscribeNext(next, error: error, completed: completed)
			disposable.addDisposable(selfDisposable)
		}
	}
}

/// Turns each value into an Optional.
private func optionalize<T, E>(signal: Signal<T, E>) -> Signal<T?, E> {
	return signal |> map { Optional.Some($0) }
}

/// Creates a RACSignal that will start() the producer once for each
/// subscription.
public func asRACSignal<T: AnyObject, E>(producer: SignalProducer<T, E>) -> RACSignal {
	return asRACSignal(producer |> optionalize)
}

/// Creates a RACSignal that will start() the producer once for each
/// subscription.
public func asRACSignal<T: AnyObject, E>(producer: SignalProducer<T?, E>) -> RACSignal {
	return RACSignal.createSignal { subscriber in
		let selfDisposable = producer.start(next: { value in
			subscriber.sendNext(value)
		}, error: { error in
			subscriber.sendError(error.nsError)
		}, completed: {
			subscriber.sendCompleted()
		})

		return RACDisposable {
			selfDisposable.dispose()
		}
	}
}

/// Creates a RACSignal that will observe the given signal.
public func asRACSignal<T: AnyObject, E>(signal: Signal<T, E>) -> RACSignal {
	return asRACSignal(signal |> optionalize)
}

/// Creates a RACSignal that will observe the given signal.
public func asRACSignal<T: AnyObject, E>(signal: Signal<T?, E>) -> RACSignal {
	return RACSignal.createSignal { subscriber in
		let selfDisposable = signal.observe(next: { value in
			subscriber.sendNext(value)
		}, error: { error in
			subscriber.sendError(error.nsError)
		}, completed: {
			subscriber.sendCompleted()
		})

		return RACDisposable {
			selfDisposable.dispose()
		}
	}
}

extension RACCommand {
	/// Creates an Action that will execute the receiver.
	///
	/// Note that the returned Action will not necessarily be marked as
	/// executing when the command is. However, the reverse is always true:
	/// the RACCommand will always be marked as executing when the action is.
	public func asAction(file: String = __FILE__, line: Int = __LINE__) -> Action<AnyObject?, AnyObject?, NSError> {
		let enabledProperty = MutableProperty(true)

		self.enabled.asSignalProducer()
			|> map { $0 as! Bool }
			|> catch { _ in SignalProducer<Bool, NoError>(value: false) }
			// FIXME: Workaround for <~ being disabled on SignalProducers.
			|> startWithSignal { signal, disposable in
				let bindDisposable = enabledProperty <~ signal
				disposable.addDisposable(bindDisposable)
			}

		return Action(enabledIf: enabledProperty) { (input: AnyObject?) -> SignalProducer<AnyObject?, NSError> in
			let executionSignal = RACSignal.defer {
				return self.execute(input)
			}

			return executionSignal.asSignalProducer(file: file, line: line)
		}
	}
}

extension Action {
	private var commandEnabled: RACSignal {
		let enabled = self.enabled.producer |> map { $0 as NSNumber }
		return asRACSignal(enabled)
	}
}

/// Creates a RACCommand that will execute the action.
///
/// Note that the returned command will not necessarily be marked as
/// executing when the action is. However, the reverse is always true:
/// the Action will always be marked as executing when the RACCommand is.
public func asRACCommand<Output: AnyObject, E>(action: Action<AnyObject?, Output, E>) -> RACCommand {
	return RACCommand(enabled: action.commandEnabled) { (input: AnyObject?) -> RACSignal in
		return asRACSignal(action.apply(input))
	}
}

/// Creates a RACCommand that will execute the action.
///
/// Note that the returned command will not necessarily be marked as
/// executing when the action is. However, the reverse is always true:
/// the Action will always be marked as executing when the RACCommand is.
public func asRACCommand<Output: AnyObject, E>(action: Action<AnyObject?, Output?, E>) -> RACCommand {
	return RACCommand(enabled: action.commandEnabled) { (input: AnyObject?) -> RACSignal in
		return asRACSignal(action.apply(input))
	}
}
