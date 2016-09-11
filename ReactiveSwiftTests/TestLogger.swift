//
//  TestLogger.swift
//  ReactiveSwift
//
//  Created by Rui Peres on 29/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation
@testable import ReactiveSwift

final class TestLogger {
	fileprivate var expectations: [(String) -> Void]
	
	init(expectations: [(String) -> Void]) {
		self.expectations = expectations
	}
}

extension TestLogger {
	func logEvent(_ identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
		expectations.removeFirst()("[\(identifier)] \(event)")
	}
}
