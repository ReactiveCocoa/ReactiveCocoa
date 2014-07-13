//
//  Bag.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// An unordered, non-unique collection of values of type T.
struct Bag<T>: Sequence {
	typealias RemovalToken = () -> UInt?

	var _next: UInt = 0
	var _elements = [UInt: T]()

	/// Adds the given value to the collection, and returns a token that can
	/// later be passed to removeValueForToken().
	mutating func add(value: T) -> RemovalToken {
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

	/// Removes a value, given the token returned from add().
	///
	/// If the value has already been removed, nothing happens.
	mutating func removeValueForToken(token: RemovalToken) {
		if let key = token() {
			self._elements.removeValueForKey(key)
		}
	}

	func generate() -> GeneratorOf<T> {
		return GeneratorOf(_elements.values.generate())
	}
}
