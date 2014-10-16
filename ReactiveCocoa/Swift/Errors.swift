//
//  Errors.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// The domain for all errors originating within the Swift components of
/// ReactiveCocoa.
///
/// For backwards compatibility reasons, the Objective-C components of
/// ReactiveCocoa use their own individual domains.
public let RACErrorDomain: NSString = "RACErrorDomain"

/// Possible error codes within `RACErrorDomain`.
public enum RACError: NSInteger {
	/// An error event occurred, but there was no `NSError` object.
	///
	/// This should only be used when bridging from Objective-C, or when
	/// invoking Objective-C APIs that may return a nil `NSError`.
	case Empty

	/// An attempt was made to execute an `Action` while it was disabled.
	case ActionNotEnabled

	/// first() or last() failed because the signal did not send at least one
	/// value before completing, or single() failed because the signal did not
	/// send exactly one value before completing.
	case ExpectedCountMismatch

	/// Returns the `RACError` that corresponds to the code within the given
	/// `NSError`, or nil if the domain of the error is not `RACErrorDomain`.
	public static func fromError(error: NSError) -> RACError? {
		if error.domain == RACErrorDomain {
			return self(rawValue: error.code)
		} else {
			return nil
		}
	}

	/// An `NSError` object corresponding to this error code.
	public var error: NSError {
		return NSError(domain: RACErrorDomain, code: rawValue, userInfo: nil)
	}
}
