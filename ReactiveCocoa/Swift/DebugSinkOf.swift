//
//  DebugSinkOf.swift
//  ReactiveCocoa
//
//  Created by Norio Nomura on 5/19/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

/// A replacement for SinkOf that allows stepping in through the debugger.
public struct DebugSinkOf<T>: SinkType {
	typealias Element = T
	
	private let putElement: T -> Void
	
	/// Construct an instance whose `put(x)` calls `putElement(x)`
	public init(_ putElement: T -> Void) {
		self.putElement = putElement
	}
	
	/// Construct an instance whose `put(x)` calls `base.put(x)`
	public init<S: SinkType where S.Element == T>(var _ base: S) {
		putElement = { base.put($0) }
	}

	/// Write `x` to this sink.
	public func put(x: T) {
		putElement(x)
	}
}
