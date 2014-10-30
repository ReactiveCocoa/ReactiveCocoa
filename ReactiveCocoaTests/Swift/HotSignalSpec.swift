//
//  HotSignalSpec.swift
//  ReactiveCocoa
//
//  Created by Alan Rogers on 30/10/2014.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveCocoa

class HotSignalSpec: QuickSpec {
	override func spec() {
		describe("replay") {
			var signal : HotSignal<Int>!
			var sink : SinkOf<Int>!
			var coldSignal : ColdSignal<Int>!

			beforeEach {
				let pipe = HotSignal<Int>.pipe()
				signal = pipe.0
				sink = pipe.1
				coldSignal = signal.replay(1)
			}

			it("should replay the first value to a subscriber") {
				sink.put(99)
				let result = coldSignal.first().value()
				expect(result).toNot(beNil())
				expect(result).to(equal(99))
			}
		}
	}
}