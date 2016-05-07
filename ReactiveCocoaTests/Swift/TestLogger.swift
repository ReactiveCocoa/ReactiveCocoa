//
//  TestLogger.swift
//  ReactiveCocoa
//
//  Created by Rui Peres on 29/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation
@testable import ReactiveCocoa

final class TestLogger {
	private var expectations: [String -> ()]
	
	init(expectations: [String -> ()]) {
		self.expectations = expectations
	}
}

extension TestLogger {
	
	func logEvent(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
		expectations.removeFirst()("[\(identifier)] \(event)")
	}
}
