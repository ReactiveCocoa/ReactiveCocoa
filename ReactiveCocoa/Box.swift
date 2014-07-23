//
//  Box.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-11.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// An immutable wrapper that can turn any value into an object.
public final class Box<T> {
	private let closure: () -> T

	/// The underlying value.
	public var value: T {
		return closure()
	}
	
	/// Initializes the box to wrap the given value.
	public init(_ value: T) {
		closure = { value }
	}
	
	/// Treats the Box as its underlying value in expressions.
	public func __conversion() -> T {
		return value
	}
}
