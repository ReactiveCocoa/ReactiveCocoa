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
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(disposable.isDisposed) == true
			}
		}

		describe("ActionDisposable") {
			it("should run the given action upon disposal") {
				var didDispose = false
				let disposable = ActionDisposable {
					didDispose = true
				}

				expect(didDispose) == false
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(didDispose) == true
				expect(disposable.isDisposed) == true
			}
		}

		describe("CompositeDisposable") {
			var disposable = CompositeDisposable()

			beforeEach {
				disposable = CompositeDisposable()
			}

			it("should ignore the addition of nil") {
				disposable.add(nil)
				return
			}

			it("should dispose of added disposables") {
				let simpleDisposable = SimpleDisposable()
				disposable += simpleDisposable

				var didDispose = false
				disposable += {
					didDispose = true
				}

				expect(simpleDisposable.isDisposed) == false
				expect(didDispose) == false
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(simpleDisposable.isDisposed) == true
				expect(didDispose) == true
				expect(disposable.isDisposed) == true
			}

			it("should not dispose of removed disposables") {
				let simpleDisposable = SimpleDisposable()
				let handle = disposable += simpleDisposable

				// We should be allowed to call this any number of times.
				handle.remove()
				handle.remove()
				expect(simpleDisposable.isDisposed) == false

				disposable.dispose()
				expect(simpleDisposable.isDisposed) == false
			}
		}

		describe("ScopedDisposable") {
			it("should dispose of the inner disposable upon deinitialization") {
				let simpleDisposable = SimpleDisposable()

				func runScoped() {
					let scopedDisposable = ScopedDisposable(simpleDisposable)
					expect(simpleDisposable.isDisposed) == false
					expect(scopedDisposable.isDisposed) == false
				}

				expect(simpleDisposable.isDisposed) == false

				runScoped()
				expect(simpleDisposable.isDisposed) == true
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
				expect(simpleDisposable.isDisposed) == false
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(disposable.innerDisposable).to(beNil())
				expect(simpleDisposable.isDisposed) == true
				expect(disposable.isDisposed) == true
			}

			it("should dispose of the previous disposable when swapping innerDisposable") {
				let oldDisposable = SimpleDisposable()
				let newDisposable = SimpleDisposable()

				disposable.innerDisposable = oldDisposable
				expect(oldDisposable.isDisposed) == false
				expect(newDisposable.isDisposed) == false

				disposable.innerDisposable = newDisposable
				expect(oldDisposable.isDisposed) == true
				expect(newDisposable.isDisposed) == false
				expect(disposable.isDisposed) == false

				disposable.innerDisposable = nil
				expect(newDisposable.isDisposed) == true
				expect(disposable.isDisposed) == false
			}
		}
	}
}
