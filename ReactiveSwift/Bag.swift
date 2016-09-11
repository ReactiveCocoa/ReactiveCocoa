//
//  Bag.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-07-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// A uniquely identifying token for removing a value that was inserted into a
/// Bag.
public final class RemovalToken {
	fileprivate var identifier: UInt?

	fileprivate init(identifier: UInt) {
		self.identifier = identifier
	}
}

/// An unordered, non-unique collection of values of type `Element`.
public struct Bag<Element> {
	fileprivate var elements: [BagElement<Element>] = []
	private var currentIdentifier: UInt = 0

	public init() {
	}

	/// Insert the given value into `self`, and return a token that can
	/// later be passed to `removeValueForToken()`.
	///
	/// - parameters:
	///   - value: A value that will be inserted.
	@discardableResult
	public mutating func insert(_ value: Element) -> RemovalToken {
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

	/// Remove a value, given the token returned from `insert()`.
	///
	/// - note: If the value has already been removed, nothing happens.
	///
	/// - parameters:
	///   - token: A token returned from a call to `insert()`.
	public mutating func remove(using token: RemovalToken) {
		if let identifier = token.identifier {
			// Removal is more likely for recent objects than old ones.
			for i in elements.indices.reversed() {
				if elements[i].identifier == identifier {
					elements.remove(at: i)
					token.identifier = nil
					break
				}
			}
		}
	}

	/// In the event of an identifier overflow (highly, highly unlikely), reset
	/// all current identifiers to reclaim a contiguous set of available
	/// identifiers for the future.
	private mutating func reindex() {
		for i in elements.indices {
			currentIdentifier = UInt(i)

			elements[i].identifier = currentIdentifier
			elements[i].token.identifier = currentIdentifier
		}
	}
}

extension Bag: Collection {
	public typealias Index = Array<Element>.Index

	public var startIndex: Index {
		return elements.startIndex
	}
	
	public var endIndex: Index {
		return elements.endIndex
	}

	public subscript(index: Index) -> Element {
		return elements[index].value
	}

	public func index(after i: Index) -> Index {
		return i + 1
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
