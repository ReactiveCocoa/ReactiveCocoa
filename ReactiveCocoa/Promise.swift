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
@final class Promise<T> {
	let _state: Atomic<_PromiseState<T>>
	var _sink = SinkOf<T?> { _ in () }

	/// A signal of the Promise's value. This will be `nil` before the promise
	/// has been resolved, and the generated value afterward.
	let signal: Signal<T?>

	/// Initializes a Promise that will run the given action when started.
	///
	/// The action must eventually `put` a value into the given sink to resolve
	/// the Promise.
	init(action: SinkOf<T> -> ()) {
		_state = Atomic(.Suspended(action))

		signal = .constant(nil)
		signal = Signal(initialValue: nil) { sink in
			self._sink = sink
		}
	}

	/// Starts the promise, if it hasn't started already.
	func start() -> Promise<T> {
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
	func await() -> T {
		let cond = NSCondition()
		cond.name = "com.github.ReactiveCocoa.Promise.await"

		start().signal.observe { _ in
			withLock(cond) {
				cond.signal()
			}
		}

		return withLock(cond) {
			while !self.signal.current {
				cond.wait()
			}

			return self.signal.current!
		}
	}

	/// Creates a Promise that will start the receiver, then run the given
	/// action and forward the results.
	func then<U>(action: T -> Promise<U>) -> Promise<U> {
		return Promise<U> { sink in
			let disposable = SerialDisposable()

			disposable.innerDisposable = self.start().signal.observe { maybeResult in
				if !maybeResult {
					return
				}

				disposable.innerDisposable = action(maybeResult!).start().signal.observe { maybeResult in
					if let result = maybeResult {
						sink.put(result)
					}
				}
			}
		}
	}
}
