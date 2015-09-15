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
/// `Next* (Error | Completed | Interrupted)?`
public enum Event<Value, Err: ErrorType> {
	/// A value provided by the signal.
	case Next(Value)

	/// The signal terminated because of an error. No further events will be
	/// received.
	case Error(Err)

	/// The signal successfully terminated. No further events will be received.
	case Completed

	/// Event production on the signal has been interrupted. No further events
	/// will be received.
	case Interrupted
	
 	public typealias Sink = Event -> ()

	/// Whether this event indicates signal termination (i.e., that no further
	/// events will be received).
	public var isTerminating: Bool {
		switch self {
		case .Next:
			return false

		case .Error:
			return true

		case .Completed:
			return true

		case .Interrupted:
			return true
		}
	}

	/// Lifts the given function over the event's value.
	public func map<U>(f: Value -> U) -> Event<U, Err> {
		switch self {
		case let .Next(value):
			return .Next(f(value))

		case let .Error(error):
			return .Error(error)

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Lifts the given function over the event's error.
	public func mapError<F>(f: Err -> F) -> Event<Value, F> {
		switch self {
		case let .Next(value):
			return .Next(value)

		case let .Error(error):
			return .Error(f(error))

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Unwraps the contained `Next` value.
	public var value: Value? {
		switch self {
		case let .Next(value):
			return value
		default:
			return nil
		}
	}

	/// Unwraps the contained `Error` value.
	public var error: Err? {
		switch self {
		case let .Error(error):
			return error
		default:
			return nil
		}
	}
	
	/// Creates a sink that can receive events of this type, then invoke the
	/// given handlers based on the kind of event received.
	public static func sink(error error: (Err -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil, next: (Value -> ())? = nil) -> Sink {
		return { event in
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
}

public func == <Value: Equatable, Err: Equatable> (lhs: Event<Value, Err>, rhs: Event<Value, Err>) -> Bool {
	switch (lhs, rhs) {
	case let (.Next(left), .Next(right)):
		return left == right

	case let (.Error(left), .Error(right)):
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

		case let .Error(error):
			return "ERROR \(error)"

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
	typealias Err: ErrorType
	/// Extracts the event from the receiver.
	var event: Event<Value, Err> { get }
}

extension Event: EventType {
	public var event: Event<Value, Err> {
		return self
	}
}

/// Puts a `Next` event into the given sink.
public func sendNext<Value, Err: ErrorType>(sink: Event<Value, Err>.Sink, _ value: Value) {
	sink(.Next(value))
}

/// Puts an `Error` event into the given sink.
public func sendError<Value, Err: ErrorType>(sink: Event<Value, Err>.Sink, _ error: Err) {
	sink(.Error(error))
}

/// Puts a `Completed` event into the given sink.
public func sendCompleted<Value, Err: ErrorType>(sink: Event<Value, Err>.Sink) {
	sink(.Completed)
}

/// Puts a `Interrupted` event into the given sink.
public func sendInterrupted<Value, Err: ErrorType>(sink: Event<Value, Err>.Sink) {
	sink(.Interrupted)
}
