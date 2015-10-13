//
//  AtomicSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
@testable import ReactiveCocoa

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

		it("should perform an action with the value") {
			let result: Bool = atomic.withValue { $0 == 1 }
			expect(result).to(beTruthy())
			expect(atomic.value).to(equal(1))
		}
	}
}

class AtomicInt32Spec : QuickSpec {
	override func spec() {
		var atomic: AtomicInt32!
		
		beforeEach {
			atomic = AtomicInt32(1)
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
		
	}
}

class AtomicInt64Spec : QuickSpec {
	override func spec() {
		var atomic: AtomicInt64!
		
		beforeEach {
			atomic = AtomicInt64(1)
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
		
	}
}

class AtomicBoolSpec : QuickSpec {
	override func spec() {
		var atomic: AtomicBool!
		
		beforeEach {
			atomic = AtomicBool(true)
		}
		
		it("should read and write the value directly") {
			expect(atomic.value).to(equal(true))
			
			atomic.value = false
			expect(atomic.value).to(equal(false))
		}
		
		it("should swap the value atomically") {
			expect(atomic.swap(false)).to(equal(true))
			expect(atomic.value).to(equal(false))
		}
		
		it("should modify the value atomically") {
			expect(atomic.modify({ !$0 })).to(equal(true))
			expect(atomic.value).to(equal(false))
		}
		
	}
}






