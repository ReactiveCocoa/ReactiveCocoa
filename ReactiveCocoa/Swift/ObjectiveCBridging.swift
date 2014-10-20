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
		return ColdSignal { subscriber in
			let next = { (obj: AnyObject?) -> () in
				subscriber.put(.Next(Box(obj)))
			}

			let error = { (maybeError: NSError?) -> () in
				let nsError = maybeError.orDefault(RACError.Empty.error)
				subscriber.put(.Error(nsError))
			}

			let completed = {
				subscriber.put(.Completed)
			}

			let disposable: RACDisposable? = self.subscribeNext(next, error: error, completed: completed)
			subscriber.disposable.addDisposable(disposable)
		}
	}

	/// Creates a HotSignal that will immediately subscriber to the underlying
	/// RACSignal, and share all received values with its observers.
	///
	/// The RACSignal must not generate an `error` event. `completed` events
	/// will be ignored.
	public func asHotSignal() -> HotSignal<AnyObject?> {
		return HotSignal { sink in
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
