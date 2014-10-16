//
//  Event.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

/// Represents a stream event.
///
/// Streams must conform to the grammar:
/// `Next* (Error | Completed)?`
public enum Event<T> {
	/// A value provided by the stream.
	case Next(Box<T>)

	/// The stream terminated because of an error.
	case Error(NSError)

	/// The stream successfully terminated.
	case Completed

	/// Whether this event indicates stream termination (from success or
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
}
