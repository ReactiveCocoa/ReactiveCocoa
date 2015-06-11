//
//  Optional.swift
//  ReactiveCocoa
//
//  Created by Neil Pankey on 6/11/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

import Foundation

/// Optional type for constraining signal extensions
public protocol OptionalType {
	typealias T
	var optional: T? { get }
}

extension Optional : OptionalType {
	public var optional: T? {
		return self
	}
}

