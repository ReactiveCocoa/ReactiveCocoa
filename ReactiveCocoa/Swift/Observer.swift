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

	/// Puts a `Next` event into `self`.
	func sendNext(value: Value)

	/// Puts a `Failed` event into `self`.
	func sendFailed(error: Error)

	/// Puts a `Completed` event into `self`.
	func sendCompleted()

	/// Puts an `Interrupted` event into `self`.
	func sendInterrupted()
}

/// An Observer is a simple wrapper around a function which can receive Events
/// (typically from a Signal).
public struct Observer<Value, Error: ErrorType> {
	public typealias Action = Event<Value, Error> -> Void

	/// An action that will be performed upon arrival of the event.
	public let action: Action

	/// An initializer that accepts a closure accepting an event for the 
	/// observer.
	///
	/// - parameters:
	///   - action: A closure to lift over received event.
	public init(_ action: Action) {
		self.action = action
	}

	/// An initializer that accepts closures for different event types.
	///
	/// - parameters:
	///   - failed: Optional closure that accepts an `Error` parameter when a
	///             `Failed` event is observed.
	///   - completed: Optional closure executed when a `Completed` event is
	///                observed.
	///   - interruped: Optional closure executed when an `Interrupted` event is
	///                 observed.
	///   - next: Optional closure executed when a `Next` event is observed.
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
	/// Puts a `Next` event into `self`.
	///
	/// - parameters:
	///   - value: A value sent with the `Next` event.
	public func sendNext(value: Value) {
		action(.Next(value))
	}

	/// Puts a `Failed` event into `self`.
	///
	/// - parameters:
	///   - error: An error object sent with `Failed` event.
	public func sendFailed(error: Error) {
		action(.Failed(error))
	}

	/// Puts a `Completed` event into `self`.
	public func sendCompleted() {
		action(.Completed)
	}

	/// Puts an `Interrupted` event into `self`.
	public func sendInterrupted() {
		action(.Interrupted)
	}
}
