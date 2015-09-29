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

/// An unordered, non-unique collection of values of type `Element`.
/// This is a class to improve memory pressure.
/// Atomicity can be ensured by using `Atomic<Bag>`.
internal class Bag<Element> {
	private var elements: [BagElement<Element>] = []
	private var currentIdentifier: UInt = 0

	init() { }

	/// Inserts the given value in the collection, and returns a token that can
	/// later be passed to removeValueForToken().
	func insert(value: Element) -> RemovalToken {
		let nextIdentifier = currentIdentifier &+ 1
		if nextIdentifier == 0 {
			reindex()
		}

		let token = RemovalToken(identifier: currentIdentifier)
		let element = BagElement(value: value, identifier: currentIdentifier, token: token)

		elements.append(element)
		currentIdentifier++

		return token
	}

	/// Removes a value, given the token returned from insert().
	///
	/// If the value has already been removed, nothing happens.
	func removeValueForToken(token: RemovalToken) {
		if let identifier = token.identifier {
			// Removal is more likely for recent objects than old ones.
			for i in (0..<elements.endIndex).reverse() {
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
	private func reindex() {
		for i in 0..<elements.endIndex {
			currentIdentifier = UInt(i)

			elements[i].identifier = currentIdentifier
			elements[i].token.identifier = currentIdentifier
		}
	}
}

extension Bag: SequenceType {
	func generate() -> AnyGenerator<Element> {
		var index = 0
		let count = elements.count

		return anyGenerator {
			if index < count {
				return self.elements[index++].value
			} else {
				return nil
			}
		}
	}
}

extension Bag: CollectionType {
	typealias Index = Array<Element>.Index

	var startIndex: Index {
		return 0
	}
	
	var endIndex: Index {
		return elements.count
	}

	subscript(index: Index) -> Element {
		return elements[index].value
	}
}

private struct BagElement<Value> {
	let value: Value
	var identifier: UInt
	let token: RemovalToken
}

extension BagElement: CustomStringConvertible {
	var description: String {
		return "BagElement(\(value))"
	}
}
