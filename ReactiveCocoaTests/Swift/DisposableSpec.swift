//
//  DisposableSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveCocoa

class DisposableSpec: QuickSpec {
	override func spec() {
		describe("SimpleDisposable") {
			it("should set disposed to true") {
				let disposable = SimpleDisposable()
				expect(disposable.disposed).to(beFalsy())

				disposable.dispose()
				expect(disposable.disposed).to(beTruthy())
			}
		}

		describe("ActionDisposable") {
			it("should run the given action upon disposal") {
				var didDispose = false
				let disposable = ActionDisposable {
					didDispose = true
				}

				expect(didDispose).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())

				disposable.dispose()
				expect(didDispose).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}
		}

		describe("CompositeDisposable") {
			var disposable = CompositeDisposable()

			beforeEach {
				disposable = CompositeDisposable()
			}

			it("should ignore the addition of nil") {
				disposable.addDisposable(nil)
				return
			}

			it("should dispose of added disposables") {
				let simpleDisposable = SimpleDisposable()
				disposable.addDisposable(simpleDisposable)

				var didDispose = false
				disposable.addDisposable {
					didDispose = true
				}

				expect(simpleDisposable.disposed).to(beFalsy())
				expect(didDispose).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())

				disposable.dispose()
				expect(simpleDisposable.disposed).to(beTruthy())
				expect(didDispose).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}

			it("should not dispose of removed disposables") {
				let simpleDisposable = SimpleDisposable()
				let handle = disposable += simpleDisposable

				// We should be allowed to call this any number of times.
				handle.remove()
				handle.remove()
				expect(simpleDisposable.disposed).to(beFalsy())

				disposable.dispose()
				expect(simpleDisposable.disposed).to(beFalsy())
			}
		}

		describe("ScopedDisposable") {
			it("should dispose of the inner disposable upon deinitialization") {
				let simpleDisposable = SimpleDisposable()

				func runScoped() {
					let scopedDisposable = ScopedDisposable(simpleDisposable)
					expect(simpleDisposable.disposed).to(beFalsy())
					expect(scopedDisposable.disposed).to(beFalsy())
				}

				expect(simpleDisposable.disposed).to(beFalsy())

				runScoped()
				expect(simpleDisposable.disposed).to(beTruthy())
			}
		}

		describe("SerialDisposable") {
			var disposable: SerialDisposable!

			beforeEach {
				disposable = SerialDisposable()
			}

			it("should dispose of the inner disposable") {
				let simpleDisposable = SimpleDisposable()
				disposable.innerDisposable = simpleDisposable

				expect(disposable.innerDisposable).notTo(beNil())
				expect(simpleDisposable.disposed).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())

				disposable.dispose()
				expect(disposable.innerDisposable).to(beNil())
				expect(simpleDisposable.disposed).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}

			it("should dispose of the previous disposable when swapping innerDisposable") {
				let oldDisposable = SimpleDisposable()
				let newDisposable = SimpleDisposable()

				disposable.innerDisposable = oldDisposable
				expect(oldDisposable.disposed).to(beFalsy())
				expect(newDisposable.disposed).to(beFalsy())

				disposable.innerDisposable = newDisposable
				expect(oldDisposable.disposed).to(beTruthy())
				expect(newDisposable.disposed).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())

				disposable.innerDisposable = nil
				expect(newDisposable.disposed).to(beTruthy())
				expect(disposable.disposed).to(beFalsy())
			}
		}
	}
}
