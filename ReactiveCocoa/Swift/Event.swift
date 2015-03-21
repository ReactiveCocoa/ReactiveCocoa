//
//  Event.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-16.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit

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
			return Event<U, E>.Next(Box(f(value.unbox)))

		case let .Error(error):
			return Event<U, E>.Error(error)

		case .Completed:
			return .Completed

		case .Interrupted:
			return .Interrupted
		}
	}

	/// Creates a sink that can receive events of this type, then invoke the
	/// given handlers based on the kind of event received.
	public static func sink(next: (T -> ())? = nil, error: (E -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil) -> SinkOf<Event> {
		return SinkOf { event in
			switch event {
			case let .Next(value):
				next?(value.unbox)

			case let .Error(err):
				error?(err.unbox)

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
		return left.unbox == right.unbox

	case let (.Error(left), .Error(right)):
		return left.unbox == right.unbox

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
			return "NEXT \(value.unbox)"

		case let .Error(error):
			return "ERROR \(error.unbox)"

		case .Completed:
			return "COMPLETED"

		case .Interrupted:
			return "INTERRUPTED"
		}
	}
}

/// Puts a `Next` event into the given sink.
public func sendNext<T, E>(sink: SinkOf<Event<T, E>>, value: T) {
	sink.put(Event<T, E>.Next(Box(value)))
}

/// Puts an `Error` event into the given sink.
public func sendError<T, E>(sink: SinkOf<Event<T, E>>, error: E) {
	sink.put(Event<T, E>.Error(Box(error)))
}

/// Puts a `Completed` event into the given sink.
public func sendCompleted<T, E>(sink: SinkOf<Event<T, E>>) {
	sink.put(Event<T, E>.Completed)
}

/// Puts a `Interrupted` event into the given sink.
public func sendInterrupted<T, E>(sink: SinkOf<Event<T, E>>) {
	sink.put(Event<T, E>.Interrupted)
}
