//
//  TestLogger.swift
//  ReactiveCocoa
//
//  Created by Rui Peres on 29/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation

#if REACTIVE_SWIFT
import ReactiveSwift
#else
import ReactiveCocoa
#endif

final class TestLogger {
	private var expectations: [String -> Void]
	
	init(expectations: [String -> Void]) {
		self.expectations = expectations
	}
}

extension TestLogger {
	
	func logEvent(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
		expectations.removeFirst()("[\(identifier)] \(event)")
	}
}
