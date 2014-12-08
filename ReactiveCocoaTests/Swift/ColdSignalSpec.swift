//
//  ColdSignalSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-12-07.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class ColdSignalSpec: QuickSpec {
	override func spec() {
		describe("zipWith") {
			it("should combine pairs") {
				let firstSignal = ColdSignal.fromValues([ 1, 2, 3 ])
				let secondSignal = ColdSignal.fromValues([ "foo", "bar", "buzz", "fuzz" ])
				
				let result = firstSignal
					.zipWith(secondSignal)
					.map { num, str in "\(num)\(str)" }
					.reduce(initial: []) { $0 + [ $1 ] }
					.first()

				expect(result.value()).to(equal([ "1foo", "2bar", "3buzz" ]))
			}
		}
	}
}
