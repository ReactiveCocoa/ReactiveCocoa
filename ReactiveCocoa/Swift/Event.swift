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
public enum Event<Value, Error: Swift.Error> {
	/// A value provided by the signal.
	case next(Value)

	/// The signal terminated because of an error. No further events will be
	/// received.
	case failed(Error)

	/// The signal successfully terminated. No further events will be received.
	case completed

	/// Event production on the signal has been interrupted. No further events
	/// will be received.
	///
	/// - important: This event does not signify the successful or failed
	///              completion of the signal.
	case interrupted

	/// Whether this event indicates signal termination (i.e., that no further
	/// events will be received).
	public var isTerminating: Bool {
		switch self {
		case .next:
			return false

		case .failed, .completed, .interrupted:
			return true
		}
	}

	/// Lift the given closure over the event's value.
	///
	/// - important: The closure is called only on `next` type events.
	///
	/// - parameters:
	///   - f: A closure that accepts a value and returns a new value
	///
	/// - returns: An event with function applied to a value in case `self` is a
	///            `next` type of event.
	public func map<U>(_ f: (Value) -> U) -> Event<U, Error> {
		switch self {
		case let .next(value):
			return .next(f(value))

		case let .failed(error):
			return .failed(error)

		case .completed:
			return .completed

		case .interrupted:
			return .interrupted
		}
	}

	/// Lift the given closure over the event's error.
	///
	/// - important: The closure is called only on failed type event.
	///
	/// - parameters:
	///   - f: A closure that accepts an error object and returns
	///        a new error object
	///
	/// - returns: An event with function applied to an error object in case
	///            `self` is a `.Failed` type of event.
	public func mapError<F>(_ f: (Error) -> F) -> Event<Value, F> {
		switch self {
		case let .next(value):
			return .next(value)

		case let .failed(error):
			return .failed(f(error))

		case .completed:
			return .completed

		case .interrupted:
			return .interrupted
		}
	}

	/// Unwrap the contained `next` value.
	public var value: Value? {
		if case let .next(value) = self {
			return value
		} else {
			return nil
		}
	}

	/// Unwrap the contained `Error` value.
	public var error: Error? {
		if case let .failed(error) = self {
			return error
		} else {
			return nil
		}
	}
}

public func == <Value: Equatable, Error: Equatable> (lhs: Event<Value, Error>, rhs: Event<Value, Error>) -> Bool {
	switch (lhs, rhs) {
	case let (.next(left), .next(right)):
		return left == right

	case let (.failed(left), .failed(right)):
		return left == right

	case (.completed, .completed):
		return true

	case (.interrupted, .interrupted):
		return true

	default:
		return false
	}
}

extension Event: CustomStringConvertible {
	public var description: String {
		switch self {
		case let .next(value):
			return "NEXT \(value)"

		case let .failed(error):
			return "FAILED \(error)"

		case .completed:
			return "COMPLETED"

		case .interrupted:
			return "INTERRUPTED"
		}
	}
}

/// Event protocol for constraining signal extensions
public protocol EventProtocol {
	/// The value type of an event.
	associatedtype Value
	/// The error type of an event. If errors aren't possible then `NoError` can
	/// be used.
	associatedtype Error: Swift.Error
	/// Extracts the event from the receiver.
	var event: Event<Value, Error> { get }
}

extension Event: EventProtocol {
	public var event: Event<Value, Error> {
		return self
	}
}
