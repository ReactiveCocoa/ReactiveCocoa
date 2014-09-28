//
//  OptionalExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-12.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit

extension Optional {
	internal func optional<U>(#ifNone: @autoclosure () -> U, ifSome: T -> U) -> U {
		if let value = self {
			return ifSome(value)
		} else {
			return ifNone()
		}
	}

	internal func orDefault(defaultValue: @autoclosure () -> T) -> T {
		return optional(ifNone: defaultValue, ifSome: identity)
	}
}
