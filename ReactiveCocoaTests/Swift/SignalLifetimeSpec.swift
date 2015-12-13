//
//  SignalLifetimeSpec.swift
//  ReactiveCocoa
//
//  Created by Vadim Yelagin on 2015-12-13.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

class SignalLifetimeSpec: QuickSpec {
	override func spec() {
		describe("init") {
			var testScheduler: TestScheduler!

			beforeEach {
				testScheduler = TestScheduler()
			}

			it("should deallocate") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { _ in nil }

				expect(signal).to(beNil())
			}

			it("should deallocate even if it has an observer") {
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }
					return signal
				}()
				expect(signal).to(beNil())
			}

			it("should deallocate even if it has an observer with retained disposable") {
				var disposable: Disposable? = nil
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }
					disposable = signal.observe(Observer())
					return signal
				}()
				expect(signal).to(beNil())
				disposable?.dispose()
				expect(signal).to(beNil())
			}

			it("should deallocate after erroring") {
				weak var signal: Signal<AnyObject, TestError>? = Signal { observer in
					testScheduler.schedule {
						observer.sendFailed(TestError.Default)
					}
					return nil
				}

				var errored = false

				signal?.observeFailed { _ in errored = true }

				expect(errored).to(beFalsy())
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(errored).to(beTruthy())
				expect(signal).to(beNil())
			}

			it("should deallocate after completing") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { observer in
					testScheduler.schedule {
						observer.sendCompleted()
					}
					return nil
				}

				var completed = false

				signal?.observeCompleted { completed = true }

				expect(completed).to(beFalsy())
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(completed).to(beTruthy())
				expect(signal).to(beNil())
			}

			it("should deallocate after interrupting") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { observer in
					testScheduler.schedule {
						observer.sendInterrupted()
					}

					return nil
				}

				var interrupted = false
				signal?.observeInterrupted {
					interrupted = true
				}

				expect(interrupted).to(beFalsy())
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(interrupted).to(beTruthy())
				expect(signal).to(beNil())
			}
		}

		describe("Signal.pipe") {
			it("should deallocate") {
				weak var signal = Signal<(), NoError>.pipe().0

				expect(signal).to(beNil())
			}

			it("should deallocate after erroring") {
				let testScheduler = TestScheduler()
				weak var weakSignal: Signal<(), TestError>?

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test: () -> () = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						observer.sendFailed(TestError.Default)
					}
				}
				test()

				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
			}

			it("should deallocate after completing") {
				let testScheduler = TestScheduler()
				weak var weakSignal: Signal<(), TestError>?

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test: () -> () = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						observer.sendCompleted()
					}
				}
				test()

				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
			}

			it("should deallocate after interrupting") {
				let testScheduler = TestScheduler()
				weak var weakSignal: Signal<(), NoError>?

				let test: () -> () = {
					let (signal, observer) = Signal<(), NoError>.pipe()
					weakSignal = signal

					testScheduler.schedule {
						observer.sendInterrupted()
					}
				}

				test()
				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
			}
		}

		describe("testTransform") {
			it("should deallocate") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { _ in nil }.testTransform()

				expect(signal).to(beNil())
			}

			it("should deallocate even if it has an observer") {
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }.testTransform()
					signal.observe(Observer())
					return signal
				}()
				expect(signal).to(beNil())
			}

			it("should deallocate even if it has an observer with retained disposable") {
				var disposable: Disposable? = nil
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }.testTransform()
					disposable = signal.observe(Observer())
					return signal
				}()
				expect(signal).to(beNil())
				disposable?.dispose()
				expect(signal).to(beNil())
			}
		}
	}
}

private extension SignalType {
	func testTransform() -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe(observer.action)
		}
	}
}
