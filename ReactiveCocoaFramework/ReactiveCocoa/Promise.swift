//
//  Promise.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-29.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

enum _PromiseState<T> {
	case Suspended(() -> T)
	case Started
}

/// Represents deferred work to generate a value of type T.
@final class Promise<T>: Observable<T?> {
	let _scheduler: Scheduler
	let _state: Atomic<_PromiseState<T>>

	var _sink = SinkOf<T?> { _ in () }

	/// Initializes a Promise that will run the given action upon the given
	/// scheduler.
	init(onScheduler scheduler: Scheduler, action: () -> T) {
		_scheduler = scheduler
		_state = Atomic(.Suspended(action))

		super.init(generator: { sink in
			sink.put(nil)
			self._sink = sink
		})
	}

	convenience init(action: () -> T) {
		self.init(onScheduler: QueueScheduler(), action: action)
	}

	/// Starts the promise, if it hasn't started already.
	func start() -> Observable<T?> {
		let oldState = _state.modify { _ in .Started }

		switch oldState {
		case let .Suspended(action):
			_scheduler.schedule {
				let result = action()
				self._sink.put(result)
			}

		default:
			break
		}

		return self
	}

	/// Starts the promise (if necessary), then blocks indefinitely on the
	/// result.
	func result() -> T {
		let cond = NSCondition()
		cond.name = "com.github.ReactiveCocoa.Promise.result"

		start().observe { _ in
			withLock(cond) {
				cond.signal()
			}
		}

		return withLock(cond) {
			while self.current == nil {
				cond.wait()
			}

			return self.current!
		}
	}

	/// Creates a Promise that will start the receiver, then run the given
	/// action and forward the results.
	func then<U>(action: T -> Promise<U>) -> Promise<U> {
		return Promise<U> {
			action(self.result()).result()
		}
	}
}
