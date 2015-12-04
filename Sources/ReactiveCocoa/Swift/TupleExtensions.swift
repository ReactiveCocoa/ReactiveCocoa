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
