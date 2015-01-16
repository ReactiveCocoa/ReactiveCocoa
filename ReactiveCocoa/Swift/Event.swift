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
public enum Event<T> {
	/// A value provided by the signal.
	case Next(Box<T>)

	/// The signal terminated because of an error.
	case Error(NSError)

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

	/// Lifts the given function over the event's value.
	public func map<U>(f: T -> U) -> Event<U> {
		switch self {
		case let .Next(box):
			return .Next(Box(f(box.unbox)))

		case let .Error(error):
			return .Error(error)

		case let .Completed:
			return .Completed
		}
	}

	/// Case analysis on the receiver.
	public func event<U>(#ifNext: T -> U, ifError: NSError -> U, ifCompleted: @autoclosure () -> U) -> U {
		switch self {
		case let .Next(box):
			return ifNext(box.unbox)

		case let .Error(err):
			return ifError(err)

		case let .Completed:
			return ifCompleted()
		}
	}

	/// Creates a sink that can receive events of this type, then invoke the
	/// given handlers based on the kind of event received.
	public static func sink(next: T -> () = doNothing, error: NSError -> () = doNothing, completed: () -> () = doNothing) -> SinkOf<Event> {
		return SinkOf { event in
			switch event {
			case let .Next(value):
				next(value.unbox)

			case let .Error(err):
				error(err)

			case .Completed:
				completed()
			}
		}
	}
}

public func == <T: Equatable> (lhs: Event<T>, rhs: Event<T>) -> Bool {
	switch (lhs, rhs) {
	case let (.Next(left), .Next(right)):
		return left.unbox == right.unbox

	case let (.Error(left), .Error(right)):
		return left == right

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
			return "ERROR \(error)"

		case .Completed:
			return "COMPLETED"
		}
	}
}

/// Puts a `Next` event into the given sink.
public func sendNext<T>(sink: SinkOf<Event<T>>, value: T) {
	sink.put(.Next(Box(value)))
}

/// Puts an `Error` event into the given sink.
public func sendError<T>(sink: SinkOf<Event<T>>, error: NSError) {
	sink.put(Event<T>.Error(error))
}

/// Puts a `Completed` event into the given sink.
public func sendCompleted<T>(sink: SinkOf<Event<T>>) {
	sink.put(Event<T>.Completed)
}
