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
				expect(disposable.disposed).to.beFalse()

				disposable.dispose()
				expect(disposable.disposed).to.beTrue()
			}
			
			it("should dispose of all copies") {
				let disposable = SimpleDisposable()
				
				let disposableCopy = disposable
				expect(disposableCopy.disposed).to.beFalse()

				disposable.dispose()
				expect(disposableCopy.disposed).to.beTrue()
			}
		}

		describe("ActionDisposable") {
			it("should run the given action upon disposal") {
				var didDispose = false
				let disposable = ActionDisposable {
					didDispose = true
				}

				expect(didDispose).to.beFalse()
				expect(disposable.disposed).to.beFalse()

				disposable.dispose()
				expect(didDispose).to.beTrue()
				expect(disposable.disposed).to.beTrue()
			}
		}

		describe("CompositeDisposable") {
			var disposable = CompositeDisposable()

			beforeEach {
				disposable = CompositeDisposable()
			}

			it("should ignore the addition of nil") {
				disposable.addDisposable(nil)
			}

			it("should dispose of added disposables") {
				let simpleDisposable = SimpleDisposable()
				disposable.addDisposable(simpleDisposable)

				var didDispose = false
				disposable.addDisposable {
					didDispose = true
				}

				expect(simpleDisposable.disposed).to.beFalse()
				expect(didDispose).to.beFalse()
				expect(disposable.disposed).to.beFalse()

				disposable.dispose()
				expect(simpleDisposable.disposed).to.beTrue()
				expect(didDispose).to.beTrue()
				expect(disposable.disposed).to.beTrue()
			}

			it("should not prune active disposables") {
				let simpleDisposable = SimpleDisposable()
				disposable.addDisposable(simpleDisposable)

				var didDispose = false
				disposable.addDisposable {
					didDispose = true
				}

				simpleDisposable.dispose()

				disposable.pruneDisposed()
				expect(didDispose).to.beFalse()

				disposable.dispose()
				expect(didDispose).to.beTrue()
			}
		}

		describe("ScopedDisposable") {
			it("should dispose of the inner disposable upon deinitialization") {
				let simpleDisposable = SimpleDisposable()

				func runScoped() {
					let scopedDisposable = ScopedDisposable(simpleDisposable)
					expect(simpleDisposable.disposed).to.beFalse()
					expect(scopedDisposable.disposed).to.beFalse()
				}

				expect(simpleDisposable.disposed).to.beFalse()

				runScoped()
				expect(simpleDisposable.disposed).to.beTrue()
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

				expect(!disposable.innerDisposable).to.beFalse()
				expect(simpleDisposable.disposed).to.beFalse()
				expect(disposable.disposed).to.beFalse()

				disposable.dispose()
				expect(!disposable.innerDisposable).to.beTrue()
				expect(simpleDisposable.disposed).to.beTrue()
				expect(disposable.disposed).to.beTrue()
			}

			it("should dispose of the previous disposable when swapping innerDisposable") {
				let oldDisposable = SimpleDisposable()
				let newDisposable = SimpleDisposable()

				disposable.innerDisposable = oldDisposable
				expect(oldDisposable.disposed).to.beFalse()
				expect(newDisposable.disposed).to.beFalse()

				disposable.innerDisposable = newDisposable
				expect(oldDisposable.disposed).to.beTrue()
				expect(newDisposable.disposed).to.beFalse()
				expect(disposable.disposed).to.beFalse()

				disposable.innerDisposable = nil
				expect(newDisposable.disposed).to.beTrue()
				expect(disposable.disposed).to.beFalse()
			}
		}
	}
}
