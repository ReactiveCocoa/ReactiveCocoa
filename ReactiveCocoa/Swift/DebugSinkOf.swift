//
//  DebugSinkOf.swift
//  ReactiveCocoa
//
//  Created by Norio Nomura on 5/19/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

public struct DebugSinkOf<T> : SinkType {
	typealias Element = T
	
	let putElement: (T) -> ()
	
	/// Construct an instance whose `put(x)` calls `putElement(x)`
	public init(_ putElement: (T) -> ()) {
		self.putElement = putElement
	}
	
	/// Construct an instance whose `put(x)` calls `base.put(x)`
	public init<S : SinkType where S.Element == T>(var _ base: S) {
		self.putElement = {base.put($0)}
	}
	
	/// Write `x` to this sink.
	public func put(x: T) {
		putElement(x)
	}
}
