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
			
			it("should run the generator immediately") {
				var didRunGenerator = false
				Signal<Int, NoError> { observer in
					didRunGenerator = true
					return nil
				}
				
				expect(didRunGenerator).to(beTrue())
			}

			it("should keep signal alive if not terminated") {
				let signal: Signal<Int, NoError> = Signal { observer in
					return nil
				}
				
				expect(signal).toNot(beNil())
			}

			it("should deallocate after erroring") {
				let scheduler = TestScheduler()
				var dealloced = false
				
				let signal: Signal<Int, NSError> = Signal { observer in
					scheduler.schedule {
						sendError(observer, testError)
					}
					return ActionDisposable {
						dealloced = true
					}
				}
				
				var errored = false
				
				signal.observe(
					next: { _ in},
					error: { _ in errored = true },
					completed: {}
				)
				
				expect(errored).to(beFalse())
				expect(dealloced).to(beFalse())
				
				scheduler.run()
				
				expect(errored).to(beTrue())
				expect(dealloced).to(beTrue())
			}

			it("should deallocate after completing") {
				let scheduler = TestScheduler()
				var dealloced = false
				
				let signal: Signal<Int, NSError> = Signal { observer in
					scheduler.schedule {
						sendCompleted(observer)
					}
					return ActionDisposable {
						dealloced = true
					}
				}
				
				var completed = false
				
				signal.observe(
					next: { _ in},
					error: { _ in },
					completed: { completed = true }
				)
				
				expect(completed).to(beFalse())
				expect(dealloced).to(beFalse())
				
				scheduler.run()
				
				expect(completed).to(beTrue())
				expect(dealloced).to(beTrue())
			}

			pending("should forward events to observers") {
			}

			pending("should dispose of returned disposable upon error") {
			}

			pending("should dispose of returned disposable upon completion") {
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
