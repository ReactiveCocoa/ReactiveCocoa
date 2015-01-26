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
			let testError = NSError(domain: "SignalSpec", code: 1, userInfo: nil)
			var testScheduler: TestScheduler!
			
			beforeEach {
				testScheduler = TestScheduler()
			}
			
			it("should run the generator immediately") {
				var didRunGenerator = false
				Signal<Int, NoError> { observer in
					didRunGenerator = true
					return nil
				}
				
				expect(didRunGenerator).to(beTruthy())
			}

			it("should keep signal alive if not terminated") {
				weak var signal: Signal<Int, NoError>? = Signal { observer in
					return nil
				}
				
				expect(signal).toNot(beNil())
			}

			pending("should deallocate after erroring") {
			}

			pending("should deallocate after completing") {
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
				
				let signal: Signal<Int, NSError> = Signal { observer in
					testScheduler.schedule {
						sendError(observer, testError)
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
				
				let signal: Signal<Int, NSError> = Signal { observer in
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
			pending("should keep signal alive if not terminated") {
			}

			pending("should deallocate after erroring") {
			}

			pending("should deallocate after completing") {
			}

			pending("should forward events to observers") {
			}
		}

		describe("observe") {
			pending("should stop forwarding events when disposed") {
			}

			pending("should not trigger side effects") {
			}

			pending("should release observer after termination") {
			}

			pending("should release observer after disposal") {
			}
		}

		describe("map") {
			pending("should transform the values of the signal") {
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
