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
	associatedtype Error: ErrorProtocol

	/// Puts a `Next` event into the given observer.
	func sendNext(_ value: Value)

	/// Puts a `Failed` event into the given observer.
	func sendFailed(_ error: Error)

	/// Puts a `Completed` event into the given observer.
	func sendCompleted()

	/// Puts an `Interrupted` event into the given observer.
	func sendInterrupted()
}

/// An Observer is a simple wrapper around a function which can receive Events
/// (typically from a Signal).
public struct Observer<Value, Error: ErrorProtocol> {
	public typealias Action = (Event<Value, Error>) -> Void

	public let action: Action

	public init(_ action: Action) {
		self.action = action
	}

	public init(failed: ((Error) -> Void)? = nil, completed: (() -> Void)? = nil, interrupted: (() -> Void)? = nil, next: ((Value) -> Void)? = nil) {
		self.init { event in
			switch event {
			case let .next(value):
				next?(value)

			case let .failed(error):
				failed?(error)

			case .completed:
				completed?()

			case .interrupted:
				interrupted?()
			}
		}
	}
}

extension Observer: ObserverType {
	/// Puts a `Next` event into the given observer.
	public func sendNext(_ value: Value) {
		action(.next(value))
	}

	/// Puts a `Failed` event into the given observer.
	public func sendFailed(_ error: Error) {
		action(.failed(error))
	}

	/// Puts a `Completed` event into the given observer.
	public func sendCompleted() {
		action(.completed)
	}

	/// Puts an `Interrupted` event into the given observer.
	public func sendInterrupted() {
		action(.interrupted)
	}
}
