//
//  BagSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveCocoa

class BagSpec: QuickSpec {
	override func spec() {
		var bag = Bag<String>()

		beforeEach {
			bag = Bag()
		}

		it("should insert values") {
			let a = bag.insert("foo")
			let b = bag.insert("bar")
			let c = bag.insert("buzz")

			expect(contains(bag, "foo")).to(beTruthy())
			expect(contains(bag, "bar")).to(beTruthy())
			expect(contains(bag, "buzz")).to(beTruthy())
			expect(contains(bag, "fuzz")).to(beFalsy())
			expect(contains(bag, "foobar")).to(beFalsy())
		}

		it("should remove values given the token from insertion") {
			let a = bag.insert("foo")
			let b = bag.insert("bar")
			let c = bag.insert("buzz")

			bag.removeValueForToken(b)
			expect(contains(bag, "foo")).to(beTruthy())
			expect(contains(bag, "bar")).to(beFalsy())
			expect(contains(bag, "buzz")).to(beTruthy())

			bag.removeValueForToken(a)
			expect(contains(bag, "foo")).to(beFalsy())
			expect(contains(bag, "bar")).to(beFalsy())
			expect(contains(bag, "buzz")).to(beTruthy())

			bag.removeValueForToken(c)
			expect(contains(bag, "foo")).to(beFalsy())
			expect(contains(bag, "bar")).to(beFalsy())
			expect(contains(bag, "buzz")).to(beFalsy())
		}
	}
}
