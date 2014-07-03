//
//  ObjectiveCBridging.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Foundation

extension RACDisposable: Disposable {}

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
	func toPromise(onScheduler scheduler: Scheduler = MainScheduler(), defaultValue: AnyObject? = nil) -> Promise<Result<AnyObject?>> {
		let property = ObservableProperty<Result<AnyObject?>?>(nil)

		let next = { (obj: AnyObject?) -> () in
			property.current = Result.Success(Box(obj))
		}

		let error = { (maybeError: NSError?) -> () in
			if let e = maybeError {
				property.current = Result.Error(e)
			} else {
				property.current = Result.Error(emptyError)
			}
		}

		let completed = { () -> () in
			// Compiler complains about an ambiguous use of `current` without
			// this.
			let observable = property as Observable<Result<AnyObject?>?>
			if observable.current == nil {
				property.current = Result.Success(Box(defaultValue))
			}
		}

		return Promise(onScheduler: QueueScheduler()) {
			scheduler.schedule {
				self
					.takeLast(1)
					.subscribeNext(next, error: error, completed: completed)
				
				return ()
			}

			let result: Result<AnyObject?>? = property.firstPassingTest { $0 != nil }
			return result!
		}
	}
}

extension RACCommand {
	/// Creates an Action that will execute the command.
	func toAction() -> Action<AnyObject?, AnyObject?> {
		let enabled: Observable<Bool> = self.enabled.toObservable().map { obj in
			if let num = obj as? NSNumber {
				return num.boolValue
			} else {
				return true
			}
		}

		return Action(enabledIf: enabled) { input in
			return RACSignal
				.defer { self.execute(input) }
				.toPromise(onScheduler: ImmediateScheduler())
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
