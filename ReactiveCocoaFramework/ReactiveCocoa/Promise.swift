//
//  Promise.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-29.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

enum _PromiseState<T> {
	case Suspended(SinkOf<T> -> ())
	case Started
}

/// Represents deferred work to generate a value of type T.
@final class Promise<T>: Signal<T?> {
	let _state: Atomic<_PromiseState<T>>
	var _sink = SinkOf<T?> { _ in () }

	/// Initializes a Promise that will run the given action when started.
	///
	/// The action must eventually `put` a value into the given sink to resolve
	/// the Promise.
	init(action: SinkOf<T> -> ()) {
		_state = Atomic(.Suspended(action))

		super.init(generator: { sink in
			sink.put(nil)
			self._sink = sink
		})
	}

	/// Initializes a Promise that will run the given synchronous action upon
	/// the given scheduler when started.
	convenience init(onScheduler scheduler: Scheduler, action: () -> T) {
		self.init(action: { sink in
			scheduler.schedule {
				let result = action()
				sink.put(result)
			}
			
			return ()
		})
	}

	/// Starts the promise, if it hasn't started already.
	func start() -> Signal<T?> {
		let oldState = _state.modify { _ in .Started }

		switch oldState {
		case let .Suspended(action):
			let disposable = SimpleDisposable()
			let disposableSink = SinkOf<T> { value in
				if disposable.disposed {
					return
				}

				disposable.dispose()
				self._sink.put(value)
			}

			action(disposableSink)

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
		return Promise<U> { sink in
			let disposable = SerialDisposable()

			disposable.innerDisposable = self.start().observe { maybeResult in
				if maybeResult == nil {
					return
				}

				disposable.innerDisposable = action(maybeResult!).start().observe { maybeResult in
					if let result = maybeResult {
						sink.put(result)
					}
				}
			}
		}
	}
}
