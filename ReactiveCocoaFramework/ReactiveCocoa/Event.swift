//
//  Event.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

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
		get {
			switch self {
			case let .Next:
				return false
			
			default:
				return true
			}
		}
	}
	
	/// Lifts the given function over the event's value.
	func map<U>(f: T -> U) -> Event<U> {
		switch self {
		case let .Next(box):
			return .Next(Box(f(box)))
			
		case let .Error(error):
			return .Error(error)
			
		case let .Completed:
			return .Completed
		}
	}
}
