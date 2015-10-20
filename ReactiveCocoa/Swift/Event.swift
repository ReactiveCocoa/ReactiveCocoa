//
//  Event.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-16.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

/// Represents a signal event.
///
/// Signals must conform to the grammar:
/// `Next* (Failed | Completed | Interrupted)?`
public enum Event<Value, Error: ErrorType> {
	/// A value provided by the signal.
	case Next(Value)

	/// The signal terminated because of an error. No further events will be
	/// received.
	case Failed(Error)

	/// The signal successfully terminated. No further events will be received.
	case Completed

	/// Event production on the signal has been interrupted. No further events
	/// will be received.
	case Interrupted


	/// Whether this event indicates signal termination (i.e., that no further
	/// events will be received).
	public var isTerminating: Bool {
		switch self {
		case .Next:
			return false

		case .Failed, .Completed, .Interrupted:
			return true
		}
	}

	/// Lifts the given function over the event's value.
	public func map<U>(f: Value -> U) -> Event<U, Error> {
		switch self {
		case let .Next(value):
			return .Next(f(value))

		case let .Failed(error):
			return .Failed(error)

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Lifts the given function over the event's error.
	public func mapError<F>(f: Error -> F) -> Event<Value, F> {
		switch self {
		case let .Next(value):
			return .Next(value)

		case let .Failed(error):
			return .Failed(f(error))

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Unwraps the contained `Next` value.
	public var value: Value? {
		if case let .Next(value) = self {
			return value
		} else {
			return nil
		}
	}

	/// Unwraps the contained `Error` value.
	public var error: Error? {
		if case let .Failed(error) = self {
			return error
		} else {
			return nil
		}
	}
}

public func == <Value: Equatable, Error: Equatable> (lhs: Event<Value, Error>, rhs: Event<Value, Error>) -> Bool {
	switch (lhs, rhs) {
	case let (.Next(left), .Next(right)):
		return left == right

	case let (.Failed(left), .Failed(right)):
		return left == right

	case (.Completed, .Completed):
		return true

	case (.Interrupted, .Interrupted):
		return true

	default:
		return false
	}
}

extension Event: CustomStringConvertible {
	public var description: String {
		switch self {
		case let .Next(value):
			return "NEXT \(value)"

		case let .Failed(error):
			return "FAILED \(error)"

		case .Completed:
			return "COMPLETED"

		case .Interrupted:
			return "INTERRUPTED"
		}
	}
}

/// Event protocol for constraining signal extensions
public protocol EventType {
	// The value type of an event.
	typealias Value
	/// The error type of an event. If errors aren't possible then `NoError` can be used.
	typealias Error: ErrorType
	/// Extracts the event from the receiver.
	var event: Event<Value, Error> { get }
}

extension Event: EventType {
	public var event: Event<Value, Error> {
		return self
	}
}
