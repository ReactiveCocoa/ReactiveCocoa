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

			it("should deallocate if it does not have any observers") {
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }
					return signal
				}()
				expect(signal).to(beNil())
			}

			it("should deallocate if no one retains it") {
				var signal: Signal<AnyObject, NoError>? = Signal { _ in nil }
				weak var weakSignal = signal

				expect(weakSignal).toNot(beNil())

				var reference = signal
				signal = nil
				expect(weakSignal).toNot(beNil())

				reference = nil
				expect(weakSignal).to(beNil())
			}

			it("should deallocate even if the generator observer is retained") {
				var observer: Signal<AnyObject, NoError>.Observer?

				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { innerObserver in
						observer = innerObserver
						return nil
					}
					return signal
				}()
				expect(observer).toNot(beNil())
				expect(signal).to(beNil())
			}

			it("should not deallocate if it has at least one observer") {
				var disposable: Disposable? = nil
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }
					disposable = signal.observe(Observer())
					return signal
				}()
				expect(signal).toNot(beNil())
				disposable?.dispose()
				expect(signal).to(beNil())
			}

			it("should be alive until erroring if it has at least one observer, despite not being explicitly retained") {
				var errored = false

				weak var signal: Signal<AnyObject, TestError>? = {
					let signal = Signal<AnyObject, TestError> { observer in
						testScheduler.schedule {
							observer.sendFailed(TestError.default)
						}
						return nil
					}
					signal.observeFailed { _ in errored = true }
					return signal
				}()

				expect(errored) == false
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(errored) == true
				expect(signal).to(beNil())
			}

			it("should be alive until completion if it has at least one observer, despite not being explicitly retained") {
				var completed = false

				weak var signal: Signal<AnyObject, NoError>? = {
					let signal = Signal<AnyObject, NoError> { observer in
						testScheduler.schedule {
							observer.sendCompleted()
						}
						return nil
					}
					signal.observeCompleted { completed = true }
					return signal
				}()

				expect(completed) == false
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(completed) == true
				expect(signal).to(beNil())
			}

			it("should be alive until interruption if it has at least one observer, despite not being explicitly retained") {
				var interrupted = false

				weak var signal: Signal<AnyObject, NoError>? = {
					let signal = Signal<AnyObject, NoError> { observer in
						testScheduler.schedule {
							observer.sendInterrupted()
						}

						return nil
					}
					signal.observeInterrupted { interrupted = true }
					return signal
				}()

				expect(interrupted) == false
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(interrupted) == true
				expect(signal).to(beNil())
			}
		}

		describe("Signal.pipe") {
			it("should deallocate") {
				weak var signal = Signal<(), NoError>.pipe().0

				expect(signal).to(beNil())
			}

			it("should be alive until erroring if it has at least one observer, despite not being explicitly retained") {
				let testScheduler = TestScheduler()
				var errored = false
				weak var weakSignal: Signal<(), TestError>?

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						// Note that the input observer has a weak reference to the signal.
						observer.sendFailed(TestError.default)
					}
					signal.observeFailed { _ in errored = true }
				}
				test()

				expect(weakSignal).toNot(beNil())
				expect(errored) == false

				testScheduler.run()
				expect(weakSignal).to(beNil())
				expect(errored) == true
			}

			it("should be alive until completion if it has at least one observer, despite not being explicitly retained") {
				let testScheduler = TestScheduler()
				var completed = false
				weak var weakSignal: Signal<(), TestError>?

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						// Note that the input observer has a weak reference to the signal.
						observer.sendCompleted()
					}
					signal.observeCompleted { completed = true }
				}
				test()

				expect(weakSignal).toNot(beNil())
				expect(completed) == false

				testScheduler.run()
				expect(weakSignal).to(beNil())
				expect(completed) == true
			}

			it("should be alive until interruption if it has at least one observer, despite not being explicitly retained") {
				let testScheduler = TestScheduler()
				var interrupted = false
				weak var weakSignal: Signal<(), NoError>?

				let test = {
					let (signal, observer) = Signal<(), NoError>.pipe()
					weakSignal = signal

					testScheduler.schedule {
						// Note that the input observer has a weak reference to the signal.
						observer.sendInterrupted()
					}

					signal.observeInterrupted { interrupted = true }
				}

				test()
				expect(weakSignal).toNot(beNil())
				expect(interrupted) == false

				testScheduler.run()
				expect(weakSignal).to(beNil())
				expect(interrupted) == true
			}
		}

		describe("testTransform") {
			it("should deallocate") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { _ in nil }.testTransform()

				expect(signal).to(beNil())
			}

			it("should not deallocate if it has at least one observer, despite not being explicitly retained") {
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }.testTransform()
					signal.observe(Observer())
					return signal
				}()
				expect(signal).toNot(beNil())
			}

			it("should not deallocate if it has at least one observer, despite not being explicitly retained") {
				var disposable: Disposable? = nil
				weak var signal: Signal<AnyObject, NoError>? = {
					let signal: Signal<AnyObject, NoError> = Signal { _ in nil }.testTransform()
					disposable = signal.observe(Observer())
					return signal
				}()
				expect(signal).toNot(beNil())
				disposable?.dispose()
				expect(signal).to(beNil())
			}

			it("should deallocate if it is unreachable and has no observer") {
				let (sourceSignal, sourceObserver) = Signal<Int, NoError>.pipe()

				var firstCounter = 0
				var secondCounter = 0
				var thirdCounter = 0

				func run() {
					_ = sourceSignal
						.map { value -> Int in
							firstCounter += 1
							return value
						}
						.map { value -> Int in
							secondCounter += 1
							return value
						}
						.map { value -> Int in
							thirdCounter += 1
							return value
						}
				}

				run()

				sourceObserver.sendNext(1)
				expect(firstCounter) == 0
				expect(secondCounter) == 0
				expect(thirdCounter) == 0

				sourceObserver.sendNext(2)
				expect(firstCounter) == 0
				expect(secondCounter) == 0
				expect(thirdCounter) == 0
			}

			it("should not deallocate if it is unreachable but still has at least one observer") {
				let (sourceSignal, sourceObserver) = Signal<Int, NoError>.pipe()

				var firstCounter = 0
				var secondCounter = 0
				var thirdCounter = 0

				var disposable: Disposable?

				func run() {
					disposable = sourceSignal
						.map { value -> Int in
							firstCounter += 1
							return value
						}
						.map { value -> Int in
							secondCounter += 1
							return value
						}
						.map { value -> Int in
							thirdCounter += 1
							return value
						}
						.observe { _ in }
				}

				run()

				sourceObserver.sendNext(1)
				expect(firstCounter) == 1
				expect(secondCounter) == 1
				expect(thirdCounter) == 1

				sourceObserver.sendNext(2)
				expect(firstCounter) == 2
				expect(secondCounter) == 2
				expect(thirdCounter) == 2

				disposable?.dispose()

				sourceObserver.sendNext(3)
				expect(firstCounter) == 2
				expect(secondCounter) == 2
				expect(thirdCounter) == 2
			}
		}

		describe("observe") {
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			var token: NSObject? = nil
			weak var weakToken: NSObject?

			func expectTokenNotDeallocated() {
				expect(weakToken).toNot(beNil())
			}

			func expectTokenDeallocated() {
				expect(weakToken).to(beNil())
			}

			beforeEach {
				let (signalTemp, observerTemp) = Signal<Int, TestError>.pipe()
				signal = signalTemp
				observer = observerTemp

				token = NSObject()
				weakToken = token

				signal.observe { [token = token] _ in
					_ = token!.description
				}
			}

			it("should deallocate observe handler when signal completes") {
				expectTokenNotDeallocated()

				observer.sendNext(1)
				expectTokenNotDeallocated()

				token = nil
				expectTokenNotDeallocated()

				observer.sendNext(2)
				expectTokenNotDeallocated()

				observer.sendCompleted()
				expectTokenDeallocated()
			}

			it("should deallocate observe handler when signal fails") {
				expectTokenNotDeallocated()

				observer.sendNext(1)
				expectTokenNotDeallocated()

				token = nil
				expectTokenNotDeallocated()

				observer.sendNext(2)
				expectTokenNotDeallocated()

				observer.sendFailed(.default)
				expectTokenDeallocated()
			}
		}
	}
}

private extension SignalProtocol {
	func testTransform() -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe(observer.action)
		}
	}
}
