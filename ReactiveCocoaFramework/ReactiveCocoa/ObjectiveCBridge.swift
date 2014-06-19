//
//  ObjectiveCBridge.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-18.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Foundation

extension RACDisposable: Disposable {}

// FIXME
let emptyError = NSError(domain: "RACErrorDomain", code: 1, userInfo: nil)

/// Creates an Observable from a RACSignal.
func fromRACSignal(signal: RACSignal) -> Observable<AnyObject?> {
	return Observable { send in
		let next = { (obj: AnyObject?) -> () in
			send(.Next(Box(obj)))
		}

		let error = { (maybeError: NSError?) -> () in
			if let e = maybeError {
				send(.Error(e))
			} else {
				send(.Error(emptyError))
			}
		}

		let completed = { send(.Completed) }

		let d: RACDisposable? = signal.subscribeNext(next, error: error, completed: completed)
		return d
	}
}

/// Creates a RACSignal from an Observable.
func toRACSignal<T: AnyObject>(observable: Observable<T?>) -> RACSignal {
	return RACSignal.createSignal { subscriber in
		let selfDisposable = observable.observe { event in
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
