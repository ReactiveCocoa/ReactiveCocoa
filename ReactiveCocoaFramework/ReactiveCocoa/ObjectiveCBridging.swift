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
	/// Creates an Enumerable from a RACSignal.
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
}

extension Enumerable {
	/// Creates a "cold" RACSignal that will enumerate over the receiver.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a stream of objects. Simply pass in the `identity` function.
	@final func toSignal<U: AnyObject>(evidence: Enumerable<T> -> Enumerable<U?>) -> RACSignal {
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
	@final func toInfiniteSignal<U: AnyObject>(evidence: Observable<T> -> Observable<U?>) -> RACSignal {
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
	@final func toSignal<U: AnyObject>(evidence: Promise<T> -> Promise<U>) -> RACSignal {
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
