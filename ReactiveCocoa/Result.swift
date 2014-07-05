//
//  Result.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-30.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a successful result or an error that occurred.
enum Result<T> {
	/// A valid, successful value was generated.
	case Success(Box<T>)

	/// An error occurred.
	case Error(NSError)

	/// Lifts the given function over the event's value.
	func map<U>(f: T -> U) -> Result<U> {
		switch self {
		case let .Success(box):
			return .Success(Box(f(box)))

		case let .Error(error):
			return .Error(error)
		}
	}

	/// Extracts an inner result from the receiver.
	///
	/// evidence - Used to prove to the typechecker that the receiver is
	///            a result containing a result. Simply pass in the `identity`
	///            function.
	///
	/// Returns the inner result if the receiver represents the `Success` case,
	/// or the error if the receiver represents the `Error` case.
	func merge<U>(evidence: Result<T> -> Result<Result<U>>) -> Result<U> {
		switch evidence(self) {
		case let .Success(result):
			return result

		case let .Error(error):
			return .Error(error)
		}
	}

	/// Case analysis on the receiver.
	func result<U>(#ifSuccess: T -> U, ifError: NSError -> U) -> U {
		switch self {
		case let .Success(value):
			return ifSuccess(value)

		case let .Error(err):
			return ifError(err)
		}
	}
}
