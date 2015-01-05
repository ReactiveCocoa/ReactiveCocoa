//
//  ObjectiveCBridging.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import LlamaKit

extension RACDisposable: Disposable {}
extension RACScheduler: DateScheduler {
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

extension MainScheduler {
	public func asRACScheduler() -> RACScheduler {
		return RACScheduler.mainThreadScheduler()
	}
}

extension QueueScheduler {
	public func asRACScheduler() -> RACScheduler {
		return RACTargetQueueScheduler(name: "org.reactivecocoa.ReactiveCocoa.QueueScheduler.asRACScheduler()", targetQueue: queue)
	}
}

extension RACSignal {
	/// Creates a ColdSignal that will produce events by subscribing to the
	/// underlying RACSignal.
	public func asColdSignal() -> ColdSignal<AnyObject?> {
		return ColdSignal { (sink, disposable) in
			let next = { (obj: AnyObject?) -> () in
				sendNext(sink, obj)
			}

			let error = { (maybeError: NSError?) -> () in
				let nsError = maybeError.orDefault(RACError.Empty.error)
				sendError(sink, nsError)
			}

			let completed = {
				sendCompleted(sink)
			}

			let selfDisposable: RACDisposable? = self.subscribeNext(next, error: error, completed: completed)
			disposable.addDisposable(selfDisposable)
		}
	}

	/// Creates a HotSignal that will immediately subscribe to the underlying
	/// RACSignal, and share all received values with its observers.
	///
	/// The RACSignal must not generate an `error` event. `completed` events
	/// will be ignored.
	public func asHotSignal() -> HotSignal<AnyObject?> {
		return HotSignal.weak { sink in
			let next = { sink.put($0) }
			let error = { (error: NSError?) in assert(false) }

			return self.subscribeNext(next, error: error)
		}
	}
}

extension ColdSignal {
	/// Creates a RACSignal that will produce events from the receiver upon each
	/// subscription.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of objects. Simply pass in the `identity` function.
	public func asDeferredRACSignal<U: AnyObject>(evidence: ColdSignal -> ColdSignal<U?>) -> RACSignal {
		return RACSignal.createSignal { subscriber in
			let selfDisposable = evidence(self).start(next: { value in
				subscriber.sendNext(value)
			}, error: { error in
				subscriber.sendError(error)
			}, completed: {
				subscriber.sendCompleted()
			})

			return RACDisposable {
				selfDisposable.dispose()
			}
		}
	}
}

extension HotSignal {
	/// Creates a RACSignal that will forward values from the receiver.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a signal of objects. Simply pass in the `identity` function.
	///
	/// Returns an infinite signal that will forward all values from the
	/// underlying HotSignal. The returned RACSignal will never complete or
	/// error, so it must be disposed manually.
	public func asInfiniteRACSignal<U: AnyObject>(evidence: HotSignal -> HotSignal<U?>) -> RACSignal {
		return RACSignal.createSignal { subscriber in
			evidence(self).observe { subscriber.sendNext($0) }
			return nil
		}
	}
}

extension RACCommand {
	/// Creates an Action that will execute the receiver.
	///
	/// Note that the returned Action will not necessarily be marked as
	/// executing when the command is. However, the reverse is always true:
	/// the RACCommand will always be marked as executing when the action is.
	public func asAction() -> Action<AnyObject?, AnyObject?> {
		let (enabled, enabledSink) = HotSignal<Bool>.pipe()
		let action = Action(enabledIf: enabled) { (input: AnyObject?) -> ColdSignal<AnyObject?> in
			return ColdSignal.lazy {
				return self.execute(input).asColdSignal()
			}
		}

		self.enabled
			.asColdSignal()
			.map { $0 as Bool }
			.start(next: { value in
				enabledSink.put(value)
			}, completed: {
				enabledSink.put(false)
			})

		return action
	}
}

extension Action {
	/// Creates a RACCommand that will execute the receiver.
	///
	/// Note that the returned command will not necessarily be marked as
	/// executing when the action is. However, the reverse is always true:
	/// the Action will always be marked as executing when the RACCommand is.
	public func asRACCommand<Output: AnyObject>(evidence: Action -> Action<AnyObject?, Output?>) -> RACCommand {
		let enabled = self.enabled.map { $0 as NSNumber? }

		return RACCommand(enabled: enabled.asDeferredRACSignal(identity)) { (input: AnyObject?) -> RACSignal in
			return evidence(self).apply(input).asDeferredRACSignal(identity)
		}
	}
}
