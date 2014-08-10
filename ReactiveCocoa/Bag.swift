//
//  Bag.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// An unordered, non-unique collection of values of type T.
internal struct Bag<T>: SequenceType {
	internal typealias RemovalToken = () -> UInt?

	private var next: UInt = 0
	private var elements = [UInt: T]()

	/// Inserts the given value in the collection, and returns a token that can
	/// later be passed to removeValueForToken().
	internal mutating func insert(value: T) -> RemovalToken {
		let start = next

		while elements[next] != nil {
			next = next &+ 1
			assert(next != start)
		}

		elements[next] = value

		var key = Optional(next)
		return {
			let k = key
			key = nil

			return k
		}
	}

	/// Removes a value, given the token returned from insert().
	///
	/// If the value has already been removed, nothing happens.
	internal mutating func removeValueForToken(token: RemovalToken) {
		if let key = token() {
			self.elements.removeValueForKey(key)
		}
	}

	internal func generate() -> GeneratorOf<T> {
		return GeneratorOf(elements.values.generate())
	}
}
