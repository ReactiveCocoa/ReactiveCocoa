//
//  Errors.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents an error that can be sent upon or received from a signal.
public protocol ErrorType {
	/// An NSError corresponding to the receiver.
	var nsError: NSError { get }
}

extension NSError: ErrorType {
	public var nsError: NSError {
		return self
	}
}

/// An “error” that is impossible to construct.
///
/// This can be used to describe signals or producers where errors will never
/// be generated. For example, `Signal<Int, NoError>` describes a signal that
/// sends integers and is guaranteed never to error out.
public enum NoError {}

extension NoError: ErrorType {
	public var nsError: NSError {
		fatalError("Impossible to construct NoError")
	}
}
