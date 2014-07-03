//
//  ObjectiveCBridging.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Foundation

extension RACDisposable: Disposable {}
extension RACScheduler: Scheduler, RepeatableScheduler {
	func schedule(action: () -> ()) -> Disposable? {
		let disposable: RACDisposable? = self.schedule(action)
		return disposable
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		let disposable: RACDisposable? = self.after(date, schedule: action)
		return disposable
	}

	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		let disposable: RACDisposable? = self.after(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, schedule: action)
		return disposable
	}
}

extension RACScheduler: BridgedScheduler {
	func asRACScheduler() -> RACScheduler {
		return self
	}
}

extension ImmediateScheduler: BridgedScheduler {
	func asRACScheduler() -> RACScheduler {
		return RACScheduler.immediateScheduler()
	}
}

extension MainScheduler: BridgedScheduler {
	func asRACScheduler() -> RACScheduler {
		return RACScheduler.mainThreadScheduler()
	}
}

extension QueueScheduler: BridgedScheduler {
	func asRACScheduler() -> RACScheduler {
		return RACTargetQueueScheduler(name: nil, targetQueue: _queue)
	}
}

// FIXME: Do something better with this.
let emptyError = NSError(domain: "RACErrorDomain", code: 1, userInfo: nil)

extension RACSignal {
	/// Creates an Enumerable that will, upon enumeration, subscribe to
	/// a RACSignal and forward all of its events.
	func toEnumerable() -> Enumerable<AnyObject?> {
		return Enumerable { enumerator in
			let next = { (obj: AnyObject?) -> () in
				enumerator.put(.Next(Box(obj)))
			}

			let error = { (maybeError: NSError?) -> () in
				if let e = maybeError {
					enumerator.put(.Error(e))
				} else {
					enumerator.put(.Error(emptyError))
				}
			}

			let completed = {
				enumerator.put(.Completed)
			}

			let disposable: RACDisposable? = self.subscribeNext(next, error: error, completed: completed)
			enumerator.disposable.addDisposable(disposable)
		}
	}

	/// Creates an Observable that will immediately subscribe to a RACSignal,
	/// and observe its latest value.
	///
	/// The signal must not generate an `error` event.
	func toObservable(initialValue: AnyObject? = nil) -> Observable<AnyObject?> {
		let property = ObservableProperty(initialValue)
		toEnumerable().bindToProperty(property)

		return property
	}

	/// Creates a Promise that will subscribe to a RACSignal when started, and
	/// yield the signal's _last_ value (or the given default value, if none are
	/// sent) after it has completed successfully.
	func toPromise(defaultValue: AnyObject? = nil) -> Promise<Result<AnyObject?>> {
		return Promise { sink in
			let next = { (obj: AnyObject?) -> () in
				sink.put(.Success(Box(obj)))
			}

			let error = { (maybeError: NSError?) -> () in
				if let e = maybeError {
					sink.put(Result.Error(e))
				} else {
					sink.put(Result.Error(emptyError))
				}
			}

			let completed = { () -> () in
				// This will only take effect if we didn't get a `Next` event.
				sink.put(.Success(Box(defaultValue)))
			}

			self.takeLast(1).subscribeNext(next, error: error, completed: completed)
			return ()
		}
	}
}

extension RACCommand {
	/// Creates an Action that will execute the command.
	func toAction() -> Action<AnyObject?, AnyObject?> {
		let enabled: Observable<Bool> = self.enabled
			.toObservable()
			.map { obj in
				if let num = obj as? NSNumber {
					return num.boolValue
				} else {
					return true
				}
			}

		return Action(enabledIf: enabled) { input in
			return RACSignal
				.defer { self.execute(input) }
				.toPromise()
		}
	}
}

extension Enumerable {
	/// Creates a "cold" RACSignal that will enumerate over the receiver.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream of objects. Simply pass in the `identity` function.
	func toSignal<U: AnyObject>(evidence: Enumerable<T> -> Enumerable<U?>) -> RACSignal {
		return RACSignal.createSignal { subscriber in
			let selfDisposable = evidence(self).enumerate { event in
				switch event {
				case let .Next(obj):
					subscriber.sendNext(obj)

				case let .Error(error):
					subscriber.sendError(error)

				case let .Completed:
					subscriber.sendCompleted()
				}
			}

			return RACDisposable {
				selfDisposable.dispose()
			}
		}
	}
}

extension Observable {
	/// Creates a "hot" RACSignal that will forward values from the receiver.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream of objects. Simply pass in the `identity` function.
	///
	/// Returns an infinite signal that will send the observable's current
	/// value, then all changes thereafter. The signal will never complete or
	/// error, so it must be disposed manually.
	func toInfiniteSignal<U: AnyObject>(evidence: Observable<T> -> Observable<U?>) -> RACSignal {
		return RACSignal.createSignal { subscriber in
			evidence(self).observe { value in
				subscriber.sendNext(value)
			}

			return nil
		}
	}
}

extension Promise {
	/// Creates a "warm" RACSignal that will start the promise upon the first
	/// subscription, and share the result with all subscribers.
	///
	/// evidence - Used to prove to the typechecker that the receiver will
	///            produce an object. Simply pass in the `identity` function.
	func toSignal<U: AnyObject>(evidence: Promise<T> -> Promise<U>) -> RACSignal {
		return RACSignal.createSignal { subscriber in
			evidence(self).start().observe { maybeResult in
				if let result = maybeResult {
					subscriber.sendNext(result)
					subscriber.sendCompleted()
				}
			}

			return nil
		}
	}
}

extension Action {
	/// Creates a RACCommand that will execute the Action.
	///
	/// evidence - Used to prove to the typechecker that the receiver accepts
	///            and produces objects. Simply pass in the `identity` function.
	func toCommand<U: AnyObject>(evidence: Action<I, O> -> Action<AnyObject?, U?>) -> RACCommand {
		let enabled = self.enabled
			.map { $0 as NSNumber? }
			.toInfiniteSignal(identity)

		return RACCommand(enabled: enabled) { input in
			return RACSignal.createSignal { subscriber in
				evidence(self).execute(input).observe { maybeResult in
					if maybeResult == nil {
						return
					}

					switch maybeResult! {
					case let .Success(obj):
						subscriber.sendNext(obj)
						subscriber.sendCompleted()

					case let .Error(error):
						subscriber.sendError(error)
					}
				}

				return nil
			}
		}
	}
}
