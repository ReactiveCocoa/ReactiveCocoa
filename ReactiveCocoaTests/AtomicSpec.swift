//
//  AtomicSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveCocoa

class AtomicSpec: QuickSpec {
	override func spec() {
		var atomic: Atomic<Int>!

		beforeEach {
			atomic = Atomic(1)
		}

		it("should read and write the value directly") {
			expect(atomic.value).to(equal(1))

			atomic.value = 2
			expect(atomic.value).to(equal(2))
		}

		it("should swap the value atomically") {
			expect(atomic.swap(2)).to(equal(1))
			expect(atomic.value).to(equal(2))
		}

		it("should modify the value atomically") {
			expect(atomic.modify({ $0 + 1 })).to(equal(1))
			expect(atomic.value).to(equal(2))
		}

		it("should modify the value and return some data") {
			let (orig, data) = atomic.modify { ($0 + 1, "foobar") }
			expect(orig).to(equal(1))
			expect(data).to(equal("foobar"))
			expect(atomic.value).to(equal(2))
		}

		it("should perform an action with the value") {
			let result: Bool = atomic.withValue { $0 == 1 }
			expect(result).to(beTruthy())
			expect(atomic.value).to(equal(1))
		}
	}
}
