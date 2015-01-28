//
//  SignalSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class SignalSpec: QuickSpec {
	override func spec() {
		describe("init") {
			var testScheduler: TestScheduler!
			
			beforeEach {
				testScheduler = TestScheduler()
			}
			
			it("should run the generator immediately") {
				var didRunGenerator = false
				Signal<AnyObject, NoError> { observer in
					didRunGenerator = true
					return nil
				}
				
				expect(didRunGenerator).to(beTruthy())
			}

			it("should keep signal alive if not terminated") {
				weak var signal: Signal<AnyObject, NoError>? = Signal.never
				
				expect(signal).toNot(beNil())
			}

			it("should deallocate after erroring") {
				weak var signal: Signal<AnyObject, TestError>? = Signal { observer in
					testScheduler.schedule {
						sendError(observer, TestError.Default)
					}
					return nil
				}
				
				var errored = false
				
				signal?.observe(error: { _ in errored = true })
				
				expect(errored).to(beFalsy())
				expect(signal).toNot(beNil())
				
				testScheduler.run()
				
				expect(errored).to(beTruthy())
				expect(signal).to(beNil())
			}

			it("should deallocate after completing") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { observer in
					testScheduler.schedule {
						sendCompleted(observer)
					}
					return nil
				}
				
				var completed = false
				
				signal?.observe(completed: { completed = true })
				
				expect(completed).to(beFalsy())
				expect(signal).toNot(beNil())
				
				testScheduler.run()
				
				expect(completed).to(beTruthy())
				expect(signal).to(beNil())
			}

			it("should forward events to observers") {
				let numbers = [ 1, 2, 5 ]
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
						sendCompleted(observer)
					}
					return nil
				}
				
				var fromSignal: [Int] = []
				var completed = false
				
				signal.observe(next: { number in
					fromSignal.append(number)
				}, completed: {
					completed = true
				})
				
				expect(completed).to(beFalsy())
				expect(fromSignal).to(beEmpty())
				
				testScheduler.run()
				
				expect(completed).to(beTruthy())
				expect(fromSignal).to(equal(numbers))
			}

			it("should dispose of returned disposable upon error") {
				let disposable = SimpleDisposable()
				
				let signal: Signal<AnyObject, TestError> = Signal { observer in
					testScheduler.schedule {
						sendError(observer, TestError.Default)
					}
					return disposable
				}
				
				var errored = false
				
				signal.observe(error: { _ in errored = true })
				
				expect(errored).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())
				
				testScheduler.run()
				
				expect(errored).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}

			it("should dispose of returned disposable upon completion") {
				let disposable = SimpleDisposable()
				
				let signal: Signal<AnyObject, NoError> = Signal { observer in
					testScheduler.schedule {
						sendCompleted(observer)
					}
					return disposable
				}
				
				var completed = false
				
				signal.observe(completed: { completed = true })
				
				expect(completed).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())
				
				testScheduler.run()
				
				expect(completed).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}
		}

		describe("Signal.pipe") {
			
			it("should keep signal alive if not terminated") {
				weak var signal = Signal<(), NoError>.pipe().0
				
				expect(signal).toNot(beNil())
			}

			pending("should deallocate after erroring") {
			}

			pending("should deallocate after completing") {
			}

			it("should forward events to observers") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				
				var fromSignal: [Int] = []
				var completed = false
				
				signal.observe(next: { number in
					fromSignal.append(number)
				}, completed: {
					completed = true
				})
				
				expect(fromSignal).to(beEmpty())
				expect(completed).to(beFalsy())
				
				sendNext(observer, 1)
				expect(fromSignal).to(equal([1]))
				
				sendNext(observer, 2)
				expect(fromSignal).to(equal([1, 2]))
				
				expect(completed).to(beFalsy())
				sendCompleted(observer)
				expect(completed).to(beTruthy())
			}
		}

		describe("observe") {
			var testScheduler: TestScheduler!
			
			beforeEach {
				testScheduler = TestScheduler()
			}
			
			it("should stop forwarding events when disposed") {
				let disposable = SimpleDisposable()
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in [1, 2] {
							sendNext(observer, number)
						}
						sendCompleted(observer)
						sendNext(observer, 4)
					}
					return disposable
				}
				
				var fromSignal: [Int] = []
				signal.observe(next: { number in
					fromSignal.append(number)
				})
				
				expect(disposable.disposed).to(beFalsy())
				expect(fromSignal).to(beEmpty())
				
				testScheduler.run()
				
				expect(disposable.disposed).to(beTruthy())
				expect(fromSignal).to(equal([1, 2]))
			}

			pending("should not trigger side effects") {
			}

			pending("should release observer after termination") {
			}

			pending("should release observer after disposal") {
			}
		}

		describe("map") {
			it("should transform the values of the signal") {
				let numbers = [ 1, 2, 5 ]
				var testScheduler = TestScheduler()
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
					}
					return nil
				}
				
				var afterMap: [Int] = []
				
				signal
				|> map { $0 * 2 }
				|> observe(next: { afterMap.append($0) })
				
				testScheduler.run()
				expect(afterMap).to(equal([2, 4, 10]))
			}
		}

		describe("filter") {
			pending("should omit values from the signal") {
			}
		}

		describe("scan") {
			pending("should incrementally accumulate a value") {
			}
		}

		describe("reduce") {
			pending("should accumulate one value") {
			}

			pending("should send the initial value if none are received") {
			}
		}

		describe("skip") {
			pending("should skip initial values") {
			}

			pending("should not skip any values when 0") {
			}
		}

		describe("skipRepeats") {
			pending("should skip duplicate Equatable values") {
			}

			pending("should skip values according to a predicate") {
			}
		}

		describe("skipWhile") {
			pending("should skip while the predicate is true") {
			}

			pending("should not skip any values when the predicate starts false") {
			}
		}

		describe("take") {
			pending("should take initial values") {
			}

			pending("should complete when 0") {
			}
		}

		describe("takeUntil") {
			pending("should take values until the trigger fires") {
			}

			pending("should complete if the trigger fires immediately") {
			}
		}

		describe("takeUntilReplacement") {
			pending("should take values from the original then the replacement") {
			}
		}

		describe("takeWhile") {
			pending("should take while the predicate is true") {
			}

			pending("should complete if the predicate starts false") {
			}
		}

		describe("observeOn") {
			pending("should send events on the given scheduler") {
			}
		}

		describe("delay") {
			pending("should send events on the given scheduler after the interval") {
			}

			pending("should schedule errors immediately") {
			}
		}

		describe("throttle") {
			pending("should send values on the given scheduler at no less than the interval") {
			}

			pending("should schedule errors immediately") {
			}
		}

		describe("sampleOn") {
			pending("should forward the latest value when the sampler fires") {
			}

			pending("should complete when both inputs have completed") {
			}
		}

		describe("combineLatestWith") {
			pending("should forward the latest values from both inputs") {
			}

			pending("should complete when both inputs have completed") {
			}
		}

		describe("zipWith") {
			pending("should combine pairs") {
			}

			pending("should complete when the shorter signal has completed") {
			}
		}

		describe("materialize") {
			pending("should reify events from the signal") {
			}
		}

		describe("dematerialize") {
			pending("should send values for Next events") {
			}

			pending("should error out for Error events") {
			}

			pending("should complete early for Completed events") {
			}
		}

		describe("takeLast") {
			pending("should send the last N values upon completion") {
			}

			pending("should send less than N values if not enough were received") {
			}
		}

		describe("timeoutWithError") {
			pending("should complete if within the interval") {
			}

			pending("should error if not completed before the interval has elapsed") {
			}
		}

		describe("try") {
			pending("should forward original values upon success") {
			}

			pending("should error if an attempt fails") {
			}
		}

		describe("tryMap") {
			pending("should forward mapped values upon success") {
			}

			pending("should error if a mapping fails") {
			}
		}
	}
}
