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
	private var expectations: [String -> Void]
	
	init(expectations: [String -> Void]) {
		self.expectations = expectations
	}
}

extension TestLogger: EventLogger {
	func logEvent(event: String) {
		expectations.removeFirst()(event)
	}
}
