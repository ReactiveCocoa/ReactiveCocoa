//
//  Promise.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents deferred work to generate a value of type T.
@final class Promise<T> {
	let _queue = dispatch_queue_create("com.github.RxSwift.Promise", DISPATCH_QUEUE_CONCURRENT)
	let _suspended = Atomic(true)

	var _result: Box<T>? = nil

	/// Initializes a promise that will generate a value using the given
	/// function, executed upon the given queue.
	init(_ work: () -> T, targetQueue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
		dispatch_set_target_queue(self._queue, targetQueue)
		dispatch_suspend(self._queue)
		
		dispatch_barrier_async(self._queue) {
			self._result = Box(work())
		}
	}
	
	/// Starts resolving the promise, if it hasn't been started already.
	func start() {
		self._suspended.modify { b in
			if b {
				dispatch_resume(self._queue)
			}
			
			return false
		}
	}
	
	/// Starts resolving the promise (if necessary), then blocks on the result.
	func result() -> T {
		self.start()
		
		// Wait for the work to finish.
		dispatch_sync(self._queue) {}
		
		return self._result!
	}
	
	/// Enqueues the given action to be performed when the promise finishes
	/// resolving.
	///
	/// This does not start the promise.
	///
	/// Returns a disposable that can be used to cancel the action before it
	/// runs.
	func whenFinished(action: T -> ()) -> Disposable {
		let disposable = SimpleDisposable()
		
		dispatch_async(self._queue) {
			if disposable.disposed {
				return
			}
		
			action(self._result!)
		}
		
		return disposable
	}

	func then<U>(action: T -> Promise<U>) -> Promise<U> {
		return Promise<U> {
			action(self.result()).result()
		}
	}
}
