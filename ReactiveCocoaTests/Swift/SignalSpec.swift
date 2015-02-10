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
			pending("should run the generator immediately") {
			}

			pending("should keep signal alive if not terminated") {
			}

			pending("should deallocate after erroring") {
			}

			pending("should deallocate after completing") {
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
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			beforeEach {
				let (baseSignal, sink) = Signal<Int, NoError>.pipe()
				signal = baseSignal |> takeWhile { $0 <= 4 }
				observer = sink
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				signal.observe(next: { value in
					latestValue = value
				}, completed: {
					completed = true
				})

				for value in -1...4 {
					sendNext(observer, value)
					expect(latestValue).to(equal(value))
					expect(completed).to(beFalse())
				}

				sendNext(observer, 5)
				expect(latestValue).to(equal(4))
				expect(completed).to(beTrue())
			}

			it("should complete if the predicate starts false") {
				var latestValue: Int?
				var completed = false

				signal.observe(next: { value in
					latestValue = value
				}, completed: {
					completed = true
				})

				sendNext(observer, 5)
				expect(latestValue).to(beNil())
				expect(completed).to(beTrue())
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
			var leftSink: Signal<Int, NoError>.Observer!
			var rightSink: Signal<String, NoError>.Observer!
			var zipped: Signal<(Int, String), NoError>!
			
			beforeEach {
				let (leftSignal, leftObserver) = Signal<Int, NoError>.pipe()
				let (rightSignal, rightObserver) = Signal<String, NoError>.pipe()
				
				leftSink = leftObserver
				rightSink = rightObserver
				zipped = leftSignal |> zipWith(rightSignal)
			}
			
			it("should combine pairs") {
				var result: [String] = []
				zipped.observe(next: { (left, right) in result.append("\(left)\(right)") })
				
				sendNext(leftSink, 1)
				sendNext(leftSink, 2)
				expect(result).to(equal([]))
				
				sendNext(rightSink, "foo")
				expect(result).to(equal([ "1foo" ]))
				
				sendNext(leftSink, 3)
				sendNext(rightSink, "bar")
				expect(result).to(equal([ "1foo", "2bar" ]))
				
				sendNext(rightSink, "buzz")
				expect(result).to(equal([ "1foo", "2bar", "3buzz" ]))
				
				sendNext(rightSink, "fuzz")
				expect(result).to(equal([ "1foo", "2bar", "3buzz" ]))
				
				sendNext(leftSink, 4)
				expect(result).to(equal([ "1foo", "2bar", "3buzz", "4fuzz" ]))
			}

			it("should complete when the shorter signal has completed") {
				var completed = false
				zipped.observe(completed: { completed = true })

				expect(completed).to(beFalsy())
				sendCompleted(leftSink)
				expect(completed).to(beTruthy())
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
