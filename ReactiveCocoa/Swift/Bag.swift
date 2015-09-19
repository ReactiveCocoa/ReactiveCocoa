//
//  Bag.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// A uniquely identifying token for removing a value that was inserted into a
/// Bag.
internal final class RemovalToken {
	private var identifier: UInt?

	private init(identifier: UInt) {
		self.identifier = identifier
	}
}

/// An unordered, non-unique collection of values of type T.
internal struct Bag<T> {
	private var elements: [BagElement<T>] = []
	private var currentIdentifier: UInt = 0

	/// Inserts the given value in the collection, and returns a token that can
	/// later be passed to removeValueForToken().
	mutating func insert(value: T) -> RemovalToken {
		let (nextIdentifier, overflow) = UInt.addWithOverflow(currentIdentifier, 1)
		if overflow {
			reindex()
		}

		let token = RemovalToken(identifier: currentIdentifier)
		let element = BagElement(value: value, identifier: currentIdentifier, token: token)

		elements.append(element)
		currentIdentifier = nextIdentifier

		return token
	}

	/// Removes a value, given the token returned from insert().
	///
	/// If the value has already been removed, nothing happens.
	mutating func removeValueForToken(token: RemovalToken) {
		if let identifier = token.identifier {
			// Removal is more likely for recent objects than old ones.
			for i in elements.indices.reverse() {
				if elements[i].identifier == identifier {
					elements.removeAtIndex(i)
					token.identifier = nil
					break
				}
			}
		}
	}

	/// In the event of an identifier overflow (highly, highly unlikely), this
	/// will reset all current identifiers to reclaim a contiguous set of
	/// available identifiers for the future.
	private mutating func reindex() {
		for i in elements.indices {
			currentIdentifier = UInt(i)

			elements[i].identifier = currentIdentifier
			elements[i].token.identifier = currentIdentifier
		}
	}
}

extension Bag: CollectionType {
	typealias Index = Array<T>.Index

	var startIndex: Index {
		return elements.startIndex
	}

	var endIndex: Index {
		return elements.endIndex
	}

	subscript(index: Index) -> T {
		return elements[index].value
	}
}

private struct BagElement<T> {
	let value: T
	var identifier: UInt
	let token: RemovalToken
}

extension BagElement: CustomStringConvertible {
	var description: String {
		return "BagElement(\(value))"
	}
}
