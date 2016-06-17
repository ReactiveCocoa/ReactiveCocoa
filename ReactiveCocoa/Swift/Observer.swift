//
//  Observer.swift
//  ReactiveCocoa
//
//  Created by Andy Matuschak on 10/2/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

/// A protocol for type-constrained extensions of `Observer`.
public protocol ObserverType {
	associatedtype Value
	associatedtype Error: ErrorType

	/// Puts a `Next` event into the given observer.
	func sendNext(value: Value)

	/// Puts a `Failed` event into the given observer.
	func sendFailed(error: Error)

	/// Puts a `Completed` event into the given observer.
	func sendCompleted()

	/// Puts an `Interrupted` event into the given observer.
	func sendInterrupted()
}

/// An Observer is a simple wrapper around a function which can receive Events
/// (typically from a Signal).
public struct Observer<Value, Error: ErrorType> {
	public typealias Action = Event<Value, Error> -> Void

	public let action: Action

	public init(_ action: Action) {
		self.action = action
	}

	public init(failed: (Error -> Void)? = nil, completed: (() -> Void)? = nil, interrupted: (() -> Void)? = nil, next: (Value -> Void)? = nil) {
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
}

extension Observer: ObserverType {
	/// Puts a `Next` event into the given observer.
	public func sendNext(value: Value) {
		action(.Next(value))
	}

	/// Puts a `Failed` event into the given observer.
	public func sendFailed(error: Error) {
		action(.Failed(error))
	}

	/// Puts a `Completed` event into the given observer.
	public func sendCompleted() {
		action(.Completed)
	}

	/// Puts an `Interrupted` event into the given observer.
	public func sendInterrupted() {
		action(.Interrupted)
	}
}
