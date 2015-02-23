//
//  Event.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-16.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit

internal func doNothing<T>(value: T) {}
internal func doNothing() {}

/// Represents a signal event.
///
/// Signals must conform to the grammar:
/// `Next* (Error | Completed)?`
public enum Event<T, E: ErrorType> {
	/// A value provided by the signal.
	case Next(Box<T>)

	/// The signal terminated because of an error.
	case Error(Box<E>)

	/// The signal successfully terminated.
	case Completed

	/// Whether this event indicates signal termination (from success or
	/// failure).
	public var isTerminating: Bool {
		switch self {
		case let .Next:
			return false

		default:
			return true
		}
	}

	/// Case analysis on the receiver.
	public func event<U>(@noescape #ifNext: T -> U, @noescape ifError: E -> U, @autoclosure ifCompleted: () -> U) -> U {
		switch self {
		case let .Next(box):
			return ifNext(box.unbox)

		case let .Error(box):
			return ifError(box.unbox)

		case let .Completed:
			return ifCompleted()
		}
	}

	/// Lifts the given function over the event's value.
	public func map<U>(f: T -> U) -> Event<U, E> {
		return event(ifNext: { value in
			return Event<U, E>.Next(Box(f(value)))
		}, ifError: { error in
			return Event<U, E>.Error(Box(error))
		}, ifCompleted: Event<U, E>.Completed)
	}

	/// Creates a sink that can receive events of this type, then invoke the
	/// given handlers based on the kind of event received.
	public static func sink(next: T -> () = doNothing, error: E -> () = doNothing, completed: () -> () = doNothing) -> SinkOf<Event> {
		return SinkOf { event in
			switch event {
			case let .Next(value):
				next(value.unbox)

			case let .Error(err):
				error(err.unbox)

			case .Completed:
				completed()
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
