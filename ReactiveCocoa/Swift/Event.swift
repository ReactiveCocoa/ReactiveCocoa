//
//  Event.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-16.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Box
import Result

/// Represents a signal event.
///
/// Signals must conform to the grammar:
/// `Next* (Error | Completed | Interrupted)?`
public enum Event<T, E: ErrorType> {
	/// A value provided by the signal.
	case Next(Box<T>)

	/// The signal terminated because of an error. No further events will be
	/// received.
	case Error(Box<E>)

	/// The signal successfully terminated. No further events will be received.
	case Completed

	/// Event production on the signal has been interrupted. No further events
	/// will be received.
	case Interrupted
	
	#if DEBUG
	public typealias Sink = DebugSinkOf<Event>
	#else
	public typealias Sink = SinkOf<Event>
	#endif

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
	public func map<U>(f: T -> U) -> Event<U, E> {
		switch self {
		case let .Next(value):
			return .Next(value.map(f))

		case let .Error(error):
			return .Error(error)

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Lifts the given function over the event's error.
	public func mapError<F>(f: E -> F) -> Event<T, F> {
		switch self {
		case let .Next(value):
			return .Next(value)

		case let .Error(error):
			return .Error(error.map(f))

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Unwraps the contained `Next` value.
	public var value: T? {
		switch self {
		case let .Next(value):
			return value.value
		default:
			return nil
		}
	}

	/// Unwraps the contained `Error` value.
	public var error: E? {
		switch self {
		case let .Error(error):
			return error.value
		default:
			return nil
		}
	}
	
	/// Creates a sink that can receive events of this type, then invoke the
	/// given handlers based on the kind of event received.
	public static func sink(error: (E -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil, next: (T -> ())? = nil) -> Sink {
		return Sink { event in
			switch event {
			case let .Next(value):
				next?(value.value)

			case let .Error(err):
				error?(err.value)

			case .Completed:
				completed?()

			case .Interrupted:
				interrupted?()
			}
		}
	}
}

public func == <T: Equatable, E: Equatable> (lhs: Event<T, E>, rhs: Event<T, E>) -> Bool {
	switch (lhs, rhs) {
	case let (.Next(left), .Next(right)):
		return left.value == right.value

	case let (.Error(left), .Error(right)):
		return left.value == right.value

	case (.Completed, .Completed):
		return true

	case (.Interrupted, .Interrupted):
		return true

	default:
		return false
	}
}

extension Event: Printable {
	public var description: String {
		switch self {
		case let .Next(value):
			return "NEXT \(value.value)"

		case let .Error(error):
			return "ERROR \(error.value)"

		case .Completed:
			return "COMPLETED"

		case .Interrupted:
			return "INTERRUPTED"
		}
	}
}

/// Puts a `Next` event into the given sink.
public func sendNext<T, E: ErrorType, S: SinkType where S.Element == Event<T, E>>(var sink: S, value: T) {
	sink.put(.Next(Box(value)))
}

/// Puts an `Error` event into the given sink.
public func sendError<T, E: ErrorType, S: SinkType where S.Element == Event<T, E>>(var sink: S, error: E) {
	sink.put(.Error(Box(error)))
}

/// Puts a `Completed` event into the given sink.
public func sendCompleted<T, E: ErrorType, S: SinkType where S.Element == Event<T, E>>(var sink: S) {
	sink.put(.Completed)
}

/// Puts a `Interrupted` event into the given sink.
public func sendInterrupted<T, E: ErrorType, S: SinkType where S.Element == Event<T, E>>(var sink: S) {
	sink.put(.Interrupted)
}
