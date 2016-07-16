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
	///
	/// - important: This event does not signify the successful or failed
	///              completion of the signal.
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

	/// Lift the given closure over the event's value.
	///
	/// - important: The closure is called only on `Next` type events.
	///
	/// - parameters:
	///   - f: A closure that accepts a value and returns a new value
	///
	/// - returns: An event with function applied to a value in case `self` is a
	///            `Next` type of event.
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

	/// Lift the given closure over the event's error.
	///
	/// - important: The closure is called only on `Failed` type event.
	///
	/// - parameters:
	///   - f: A closure that accepts an error object and returns
	///        a new error object
	///
	/// - returns: An event with function applied to an error object in case
	///            `self` is a `.Failed` type of event.
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

	/// Unwrap the contained `Next` value.
	public var value: Value? {
		if case let .Next(value) = self {
			return value
		} else {
			return nil
		}
	}

	/// Unwrap the contained `Error` value.
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
	/// The value type of an event.
	associatedtype Value
	/// The error type of an event. If errors aren't possible then `NoError` can
	/// be used.
	associatedtype Error: ErrorType
	/// Extracts the event from the receiver.
	var event: Event<Value, Error> { get }
}

extension Event: EventType {
	public var event: Event<Value, Error> {
		return self
	}
}
