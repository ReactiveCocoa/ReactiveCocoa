//
//  Observer.swift
//  ReactiveCocoa
//
//  Created by Andy Matuschak on 10/2/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

/// An Observer is a simple wrapper around a function which can receive Events
/// (typically from a Signal).
public struct Observer<Value, Err: ErrorType> {
	public typealias Action = Event<Value, Err> -> ()

	public let action: Action

	public init(_ action: Action) {
		self.action = action
	}

	public init(error: (Err -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil, next: (Value -> ())? = nil) {
		self.init { event in
			switch event {
			case let .Next(value):
				next?(value)

			case let .Error(err):
				error?(err)

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

	/// Puts an `Error` event into the given observer.
	public func sendError(error: Err) {
		action(.Error(error))
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
