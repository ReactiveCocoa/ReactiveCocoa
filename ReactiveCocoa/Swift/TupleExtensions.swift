//
//  TupleExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-12-20.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Adds a value into an N-tuple, returning an (N+1)-tuple.
///
/// Supports creating tuples up to 10 elements long.
internal func repack<A, B, C>(t: (A, B), value: C) -> (A, B, C) {
	return (t.0, t.1, value)
}

internal func repack<A, B, C, D>(t: (A, B, C), value: D) -> (A, B, C, D) {
	return (t.0, t.1, t.2, value)
}

internal func repack<A, B, C, D, E>(t: (A, B, C, D), value: E) -> (A, B, C, D, E) {
	return (t.0, t.1, t.2, t.3, value)
}

internal func repack<A, B, C, D, E, F>(t: (A, B, C, D, E), value: F) -> (A, B, C, D, E, F) {
	return (t.0, t.1, t.2, t.3, t.4, value)
}

internal func repack<A, B, C, D, E, F, G>(t: (A, B, C, D, E, F), value: G) -> (A, B, C, D, E, F, G) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, value)
}

internal func repack<A, B, C, D, E, F, G, H>(t: (A, B, C, D, E, F, G), value: H) -> (A, B, C, D, E, F, G, H) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, t.6, value)
}

internal func repack<A, B, C, D, E, F, G, H, I>(t: (A, B, C, D, E, F, G, H), value: I) -> (A, B, C, D, E, F, G, H, I) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, value)
}

internal func repack<A, B, C, D, E, F, G, H, I, J>(t: (A, B, C, D, E, F, G, H, I), value: J) -> (A, B, C, D, E, F, G, H, I, J) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, t.8, value)
}


// This will extend 'indexable' collections that can use an integer Index, 
/// like Arrays to allow some conviences tuple implementations
public extension SequenceType where Self:Indexable, Self.Index : IntegerLiteralConvertible {
	
	private func _get_element<T>(index : Index) -> T {
		let x = self[index]
		let t = x as? T
		precondition(t != nil, "\(x) is not of type \(T.self) at index \(index) of \(Self.self)")
		return t!
	}
	
	public func toTuple<A,B>() -> (A,B) {
		return
			(self._get_element(0),
				self._get_element(1))
	}
	public func toTuple<A, B, C>() -> (A, B, C) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2))
	}
	public func toTuple<A, B, C, D>() -> (A, B, C, D) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3))
	}
	public func toTuple<A, B, C, D, E>() -> (A, B, C, D, E) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4))
	}
	public func toTuple<A, B, C, D, E, F>() -> (A, B, C, D, E, F) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5))
	}
	public func toTuple<A, B, C, D, E, F, G>() -> (A, B, C, D, E, F, G) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5),
			self._get_element(6))
	}
	public func toTuple<A, B, C, D, E, F, G, H>() -> (A, B, C, D, E, F, G, H) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5),
			self._get_element(6),
			self._get_element(7))
	}
	public func toTuple<A, B, C, D, E, F, G, H, I>() -> (A, B, C, D, E, F, G, H, I) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5),
			self._get_element(6),
			self._get_element(7),
			self._get_element(8))
	}
	public func toTuple<A, B, C, D, E, F, G, H, I, J>() -> (A, B, C, D, E, F, G, H, I, J) {
		return (self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5),
			self._get_element(6),
			self._get_element(7),
			self._get_element(8),
			self._get_element(9))
	}
	public func toTuple<A, B, C, D, E, F, G, H, I, J, K>() -> (A, B, C, D, E, F, G, H, I, J, K) {
		return (
			self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5),
			self._get_element(6),
			self._get_element(7),
			self._get_element(8),
			self._get_element(9),
			self._get_element(10))
	}
	public func toTuple<A, B, C, D, E, F, G, H, I, J, K, L>() -> (A, B, C, D, E, F, G, H, I, J, K, L) {
		return (self._get_element(0),
			self._get_element(1),
			self._get_element(2),
			self._get_element(3),
			self._get_element(4),
			self._get_element(5),
			self._get_element(6),
			self._get_element(7),
			self._get_element(8),
			self._get_element(9),
			self._get_element(10),
			self._get_element(11))
	}
}
