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
				expect(disposable.disposed) == false

				disposable.dispose()
				expect(disposable.disposed) == true
			}
		}

		describe("ActionDisposable") {
			it("should run the given action upon disposal") {
				var didDispose = false
				let disposable = ActionDisposable {
					didDispose = true
				}

				expect(didDispose) == false
				expect(disposable.disposed) == false

				disposable.dispose()
				expect(didDispose) == true
				expect(disposable.disposed) == true
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

				expect(simpleDisposable.disposed) == false
				expect(didDispose) == false
				expect(disposable.disposed) == false

				disposable.dispose()
				expect(simpleDisposable.disposed) == true
				expect(didDispose) == true
				expect(disposable.disposed) == true
			}

			it("should not dispose of removed disposables") {
				let simpleDisposable = SimpleDisposable()
				let handle = disposable += simpleDisposable

				// We should be allowed to call this any number of times.
				handle.remove()
				handle.remove()
				expect(simpleDisposable.disposed) == false

				disposable.dispose()
				expect(simpleDisposable.disposed) == false
			}
		}

		describe("ScopedDisposable") {
			it("should dispose of the inner disposable upon deinitialization") {
				let simpleDisposable = SimpleDisposable()

				func runScoped() {
					let scopedDisposable = ScopedDisposable(simpleDisposable)
					expect(simpleDisposable.disposed) == false
					expect(scopedDisposable.disposed) == false
				}

				expect(simpleDisposable.disposed) == false

				runScoped()
				expect(simpleDisposable.disposed) == true
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
				expect(simpleDisposable.disposed) == false
				expect(disposable.disposed) == false

				disposable.dispose()
				expect(disposable.innerDisposable).to(beNil())
				expect(simpleDisposable.disposed) == true
				expect(disposable.disposed) == true
			}

			it("should dispose of the previous disposable when swapping innerDisposable") {
				let oldDisposable = SimpleDisposable()
				let newDisposable = SimpleDisposable()

				disposable.innerDisposable = oldDisposable
				expect(oldDisposable.disposed) == false
				expect(newDisposable.disposed) == false

				disposable.innerDisposable = newDisposable
				expect(oldDisposable.disposed) == true
				expect(newDisposable.disposed) == false
				expect(disposable.disposed) == false

				disposable.innerDisposable = nil
				expect(newDisposable.disposed) == true
				expect(disposable.disposed) == false
			}
		}
	}
}
