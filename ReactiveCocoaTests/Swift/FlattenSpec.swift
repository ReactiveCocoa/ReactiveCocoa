//
//  FlattenSpec.swift
//  ReactiveCocoa
//
//  Created by Oleg Shnitko on 1/22/16.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

private extension SignalType {
	typealias Pipe = (Signal<Value, Error>, Observer<Value, Error>)
}

private typealias Pipe = Signal<SignalProducer<Int, TestError>, TestError>.Pipe

class FlattenSpec: QuickSpec {
	override func spec() {

		describe("Signal.switchToLatest") {

			var pipe: Pipe!
			var disposable: Disposable?

			beforeEach {
				pipe = Signal.pipe()
				disposable = pipe.0.flatten(.Latest).observe { _ in }
			}

			afterEach {
				disposable?.dispose()
			}

			context("disposing") {
				var disposed = false

				beforeEach {
					disposed = false
					pipe.1.sendNext(SignalProducer<Int, TestError> { _, disposable in
						disposable += ActionDisposable {
							disposed = true
						}
					})
				}

				it("should dispose inner signals when outer signal interrupted") {
					pipe.1.sendInterrupted()
					expect(disposed).to(beTrue())
				}

				it("should dispose inner signals when outer signal failed") {
					pipe.1.sendFailed(TestError.Default)
					expect(disposed).to(beTrue())
				}

				it("should not dispose inner signals when outer signal completed") {
					pipe.1.sendCompleted()
					expect(disposed).to(beFalse())
				}
			}
		}

		describe("Signal.merge") {

			var pipe: Pipe!
			var disposable: Disposable?

			beforeEach {
				pipe = Signal.pipe()
				disposable = pipe.0.flatten(.Merge).observe { _ in }
			}

			afterEach {
				disposable?.dispose()
			}

			context("disposing") {
				var disposed = false

				beforeEach {
					disposed = false
					pipe.1.sendNext(SignalProducer<Int, TestError> { _, disposable in
						disposable += ActionDisposable {
							disposed = true
						}
					})
				}

				it("should dispose inner signals when outer signal interrupted") {
					pipe.1.sendInterrupted()
					expect(disposed).to(beTrue())
				}

				it("should dispose inner signals when outer signal failed") {
					pipe.1.sendFailed(TestError.Default)
					expect(disposed).to(beTrue())
				}

				it("should not dispose inner signals when outer signal completed") {
					pipe.1.sendCompleted()
					expect(disposed).to(beFalse())
				}
			}
		}

		describe("Signal.concat") {

			var pipe: Pipe!
			var disposable: Disposable?

			beforeEach {
				pipe = Signal.pipe()
				disposable = pipe.0.flatten(.Concat).observe { _ in }
			}

			afterEach {
				disposable?.dispose()
			}

			context("disposing") {
				var disposed = false

				beforeEach {
					disposed = false
					pipe.1.sendNext(SignalProducer<Int, TestError> { _, disposable in
						disposable += ActionDisposable {
							disposed = true
						}
					})
				}

				it("should dispose inner signals when outer signal interrupted") {
					pipe.1.sendInterrupted()
					expect(disposed).to(beTrue())
				}

				it("should dispose inner signals when outer signal failed") {
					pipe.1.sendFailed(TestError.Default)
					expect(disposed).to(beTrue())
				}

				it("should not dispose inner signals when outer signal completed") {
					pipe.1.sendCompleted()
					expect(disposed).to(beFalse())
				}
			}
		}

		describe("SignalProducer.switchToLatest") {
			it("disposes original signal when result signal interrupted") {
				
				var disposed = false

				let disposable = SignalProducer<SignalProducer<Void, NoError>, NoError> { observer, disposable in
					disposable += ActionDisposable {
						disposed = true
					}
				}.flatten(.Latest).start()

				disposable.dispose()
				expect(disposed).to(beTrue())
			}
		}

		describe("SignalProducer.merge") {
			it("disposes original signal when result signal interrupted") {

				var disposed = false

				let disposable = SignalProducer<SignalProducer<Void, NoError>, NoError> { observer, disposable in
					disposable += ActionDisposable {
						disposed = true
					}
				}.flatten(.Merge).start()

				disposable.dispose()
				expect(disposed).to(beTrue())
			}
		}

		describe("SignalProducer.concat") {
			it("disposes original signal when result signal interrupted") {

				var disposed = false

				let disposable = SignalProducer<SignalProducer<Void, NoError>, NoError> { observer, disposable in
					disposable += ActionDisposable {
						disposed = true
					}
				}.flatten(.Concat).start()

				disposable.dispose()
				expect(disposed).to(beTrue())
			}
		}
	}
}
