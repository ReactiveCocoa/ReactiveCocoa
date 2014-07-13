//
//  OptionalExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-12.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

extension Optional {
	func optional<U>(#ifNone: @auto_closure () -> U, ifSome: T -> U) -> U {
		if let value = self {
			return ifSome(value)
		} else {
			return ifNone()
		}
	}

	func orDefault(defaultValue: @auto_closure () -> T) -> T {
		return optional(ifNone: defaultValue, ifSome: identity)
	}
}
