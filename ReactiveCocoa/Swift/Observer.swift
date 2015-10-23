//
//  Observer.swift
//  ReactiveCocoa
//
//  Created by Andy Matuschak on 10/2/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

/// An Observer is a simple wrapper around a function which can receive Events
/// (typically from a Signal).
public struct Observer<Value, Error: ErrorType> {
	public typealias Action = Event<Value, Error> -> ()

	public let action: Action

	public init(_ action: Action) {
		self.action = action
	}

	public init(failed: (Error -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil, next: (Value -> ())? = nil) {
		self.init { event in
			switch event {
			case let .Next(value):
				next?(value)

			case let .Failed(error):
				failed?(error)

			case .Completed:
				completed?()

			case .Interrupted:
				interrupted?()
			}
		}
	}

	/// Puts a `Next` event into the given observer.
	public func sendNext(value: Value) {
		action(.Next(value))
	}

	/// Puts an `Failed` event into the given observer.
	public func sendFailed(error: Error) {
		action(.Failed(error))
	}

	/// Puts a `Completed` event into the given observer.
	public func sendCompleted() {
		action(.Completed)
	}

	/// Puts a `Interrupted` event into the given observer.
	public func sendInterrupted() {
		action(.Interrupted)
	}
}
