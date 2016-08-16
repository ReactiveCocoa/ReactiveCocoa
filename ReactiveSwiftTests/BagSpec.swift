//
//  BagSpec.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveSwift

class BagSpec: QuickSpec {
	override func spec() {
		var bag = Bag<String>()

		beforeEach {
			bag = Bag()
		}

		it("should insert values") {
			bag.insert("foo")
			bag.insert("bar")
			bag.insert("buzz")

			expect(bag).to(contain("foo"))
			expect(bag).to(contain("bar"))
			expect(bag).to(contain("buzz"))
			expect(bag).toNot(contain("fuzz"))
			expect(bag).toNot(contain("foobar"))
		}

		it("should remove values given the token from insertion") {
			let a = bag.insert("foo")
			let b = bag.insert("bar")
			let c = bag.insert("buzz")

			bag.remove(using: b)
			expect(bag).to(contain("foo"))
			expect(bag).toNot(contain("bar"))
			expect(bag).to(contain("buzz"))

			bag.remove(using: a)
			expect(bag).toNot(contain("foo"))
			expect(bag).toNot(contain("bar"))
			expect(bag).to(contain("buzz"))

			bag.remove(using: c)
			expect(bag).toNot(contain("foo"))
			expect(bag).toNot(contain("bar"))
			expect(bag).toNot(contain("buzz"))
		}
	}
}
