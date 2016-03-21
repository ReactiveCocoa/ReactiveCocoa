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
			expect(atomic.value) == 1

			atomic.value = 2
			expect(atomic.value) == 2
		}

		it("should swap the value atomically") {
			expect(atomic.swap(2)) == 1
			expect(atomic.value) == 2
		}

		it("should modify the value atomically") {
			expect(atomic.modify({ $0 + 1 })) == 1
			expect(atomic.value) == 2
		}

		it("should perform an action with the value") {
			let result: Bool = atomic.withValue { $0 == 1 }
			expect(result) == true
			expect(atomic.value) == 1
		}
	}
}
