//
//  Event.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import swiftz_core

/// Represents a stream event.
///
/// Streams must conform to the grammar:
/// `Next* (Error | Completed)?`
enum Event<T> {
	/// A value provided by the stream.
	case Next(Box<T>)

	/// The stream terminated because of an error.
	case Error(NSError)

	/// The stream successfully terminated.
	case Completed
	
	/// Whether this event indicates stream termination (from success or
	/// failure).
	var isTerminating: Bool {
		switch self {
		case let .Next:
			return false
		
		default:
			return true
		}
	}

	/// Case analysis on the receiver.
	func event<U>(#ifNext: T -> U, ifError: NSError -> U, ifCompleted: @auto_closure () -> U) -> U {
		switch self {
		case let .Next(box):
			return ifNext(box.value)

		case let .Error(err):
			return ifError(err)

		case let .Completed:
			return ifCompleted()
		}
	}
}
