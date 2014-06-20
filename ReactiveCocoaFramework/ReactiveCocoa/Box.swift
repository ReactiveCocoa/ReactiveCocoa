//
//  Box.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-11.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An immutable wrapper that can turn any value into an object.
@final class Box<T> {
	let _closure: () -> T

	/// The underlying value.
	var value: T {
		get {
			return _closure()
		}
	}
	
	/// Initializes the box to wrap the given value.
	init(_ value: T) {
		_closure = { value }
	}
	
	@conversion
	func __conversion() -> T {
		return value
	}
}
