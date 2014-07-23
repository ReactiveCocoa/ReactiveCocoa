//
//  Bag.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// An unordered, non-unique collection of values of type T.
internal struct Bag<T>: Sequence {
	public typealias RemovalToken = () -> UInt?

	private var _next: UInt = 0
	private var _elements = [UInt: T]()

	/// Inserts the given value in the collection, and returns a token that can
	/// later be passed to removeValueForToken().
	public mutating func insert(value: T) -> RemovalToken {
		let start = _next

		while _elements[_next] {
			_next = _next &+ 1
			assert(_next != start)
		}

		_elements[_next] = value

		var key = Optional(_next)
		return {
			let k = key
			key = nil

			return k
		}
	}

	/// Removes a value, given the token returned from insert().
	///
	/// If the value has already been removed, nothing happens.
	public mutating func removeValueForToken(token: RemovalToken) {
		if let key = token() {
			self._elements.removeValueForKey(key)
		}
	}

	public func generate() -> GeneratorOf<T> {
		return GeneratorOf(_elements.values.generate())
	}
}
