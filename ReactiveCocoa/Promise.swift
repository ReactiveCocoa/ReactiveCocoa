//
//  Promise.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-29.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

private enum PromiseState<T> {
	case Suspended(SinkOf<T> -> ())
	case Started
}

/// Represents deferred work to generate a value of type T.
public final class Promise<T> {
	private let state: Atomic<PromiseState<T>>
	private let sink: SinkOf<T?>

	/// A signal of the Promise's value. This will be `nil` before the promise
	/// has been resolved, and the generated value afterward.
	public let signal: Signal<T?>

	/// Initializes a Promise that will run the given action when started.
	///
	/// The action must eventually `put` a value into the given sink to resolve
	/// the Promise.
	public init(action: SinkOf<T> -> ()) {
		state = Atomic(.Suspended(action))
		(signal, sink) = Signal.pipeWithInitialValue(nil)
	}

	/// Starts the promise, if it hasn't started already.
	public func start() -> Promise<T> {
		let oldState = state.modify { _ in .Started }

		switch oldState {
		case let .Suspended(action):
			// Hold on to the `action` closure until the promise is resolved.
			let disposable = ActionDisposable { [action] in }

			let disposableSink = SinkOf<T> { [weak self] value in
				if disposable.disposed {
					return
				}

				disposable.dispose()
				self?.sink.put(value)
			}

			action(disposableSink)

		default:
			break
		}

		return self
	}

	/// Starts the promise (if necessary), then blocks indefinitely on the
	/// result.
	public func await() -> T {
		let cond = NSCondition()
		cond.name = "com.github.ReactiveCocoa.Promise.await"

		start().signal.observe { _ in
			cond.lock()
			cond.signal()
			cond.unlock()
		}

		cond.lock()
		while !self.signal.current {
			cond.wait()
		}

		let result = self.signal.current!
		cond.unlock()

		return result
	}

	/// Creates a Promise that will start the receiver, then run the given
	/// action and forward the results.
	public func then<U>(action: T -> Promise<U>) -> Promise<U> {
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
