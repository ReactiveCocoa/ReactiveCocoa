//
//  TypeEquality.swift
//  swiftz
//
//  Created by Maxwell Swadling on 19/06/2014.
//  Copyright (c) 2014 Maxwell Swadling. All rights reserved.
//

import Foundation

// For more info, see:
// http://hackage.haskell.org/package/type-equality-0.1.2/docs/Data-Type-Equality.html
protocol TypeEquality {
	typealias From
	typealias To

	func apply(a: From) -> To
}

@final class Refl<X> : TypeEquality {
	typealias From = X
	typealias To = X

	func apply(a: From) -> To {
		return a
	}
}
