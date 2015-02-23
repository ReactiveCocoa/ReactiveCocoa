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
			it("should transform the values of the signal") {
				let (signal, sink) = Signal<Int, NoError>.pipe()
				let mappedSignal = signal |> map { String($0 + 1) }

				var lastValue: String?

				mappedSignal.observe(next: {
					lastValue = $0
					return
				})

				expect(lastValue).to(beNil())

				sendNext(sink, 0)
				expect(lastValue).to(equal("1"))

				sendNext(sink, 1)
				expect(lastValue).to(equal("2"))
			}
		}

		describe("filter") {
			it("should omit values from the signal") {
				let (signal, sink) = Signal<Int, NoError>.pipe()
				let mappedSignal = signal |> filter { $0 % 2 == 0 }

				var lastValue: Int?

				mappedSignal.observe(next: { lastValue = $0 })

				expect(lastValue).to(beNil())

				sendNext(sink, 0)
				expect(lastValue).to(equal(0))

				sendNext(sink, 1)
				expect(lastValue).to(equal(0))

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("scan") {
			it("should incrementally accumulate a value") {
				let (baseSignal, sink) = Signal<String, NoError>.pipe()
				let signal = baseSignal |> scan("", +)

				var lastValue: String?

				signal.observe(next: { lastValue = $0 })

				expect(lastValue).to(beNil())

				sendNext(sink, "a")
				expect(lastValue).to(equal("a"))

				sendNext(sink, "bb")
				expect(lastValue).to(equal("abb"))
			}
		}

		describe("reduce") {
			it("should accumulate one value") {
				let (baseSignal, sink) = Signal<Int, NoError>.pipe()
				let signal = baseSignal |> reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe(next: {
					lastValue = $0
				}, completed: {
					completed = true
				})

				expect(lastValue).to(beNil())

				sendNext(sink, 1)
				expect(lastValue).to(beNil())

				sendNext(sink, 2)
				expect(lastValue).to(beNil())

				expect(completed).to(beFalse())
				sendCompleted(sink)
				expect(completed).to(beTrue())

				expect(lastValue).to(equal(4))
			}

			it("should send the initial value if none are received") {
				let (baseSignal, sink) = Signal<Int, NoError>.pipe()
				let signal = baseSignal |> reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe(next: {
					lastValue = $0
				}, completed: {
					completed = true
				})

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sendCompleted(sink)

				expect(lastValue).to(equal(1))
				expect(completed).to(beTrue())
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let (baseSignal, sink) = Signal<Int, NoError>.pipe()
				let signal = baseSignal |> skip(1)

				var lastValue: Int?
				signal.observe(next: { lastValue = $0 })

				expect(lastValue).to(beNil())

				sendNext(sink, 1)
				expect(lastValue).to(beNil())

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))
			}

			it("should not skip any values when 0") {
				let (baseSignal, sink) = Signal<Int, NoError>.pipe()
				let signal = baseSignal |> skip(0)

				var lastValue: Int?
				signal.observe(next: { lastValue = $0 })

				expect(lastValue).to(beNil())

				sendNext(sink, 1)
				expect(lastValue).to(equal(1))

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseSignal, sink) = Signal<Bool, NoError>.pipe()
				let signal = baseSignal |> skipRepeats

				var values: [Bool] = []
				signal.observe(next: { values.append($0) })

				expect(values).to(equal([]))

				sendNext(sink, true)
				expect(values).to(equal([true]))

				sendNext(sink, true)
				expect(values).to(equal([true]))

				sendNext(sink, false)
				expect(values).to(equal([true, false]))

				sendNext(sink, true)
				expect(values).to(equal([true, false, true]))
			}

			it("should skip values according to a predicate") {
				let (baseSignal, sink) = Signal<String, NoError>.pipe()
				let signal = baseSignal |> skipRepeats { countElements($0) == countElements($1) }

				var values: [String] = []
				signal.observe(next: { values.append($0) })

				expect(values).to(equal([]))

				sendNext(sink, "a")
				expect(values).to(equal(["a"]))

				sendNext(sink, "b")
				expect(values).to(equal(["a"]))

				sendNext(sink, "cc")
				expect(values).to(equal(["a", "cc"]))

				sendNext(sink, "d")
				expect(values).to(equal(["a", "cc", "d"]))
			}
		}

		describe("skipWhile") {
			var signal: Signal<Int, NoError>!
			var sink: Signal<Int, NoError>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()

				signal = baseSignal |> skipWhile { $0 < 2 }
				sink = observer
				lastValue = nil

				signal.observe(next: { lastValue = $0 })
			}

			it("should skip while the predicate is true") {
				expect(lastValue).to(beNil())

				sendNext(sink, 1)
				expect(lastValue).to(beNil())

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))

				sendNext(sink, 0)
				expect(lastValue).to(equal(0))
			}

			it("should not skip any values when the predicate starts false") {
				expect(lastValue).to(beNil())

				sendNext(sink, 3)
				expect(lastValue).to(equal(3))

				sendNext(sink, 1)
				expect(lastValue).to(equal(1))
			}
		}

		describe("take") {
			it("should take initial values") {
				let (baseSignal, sink) = Signal<Int, NoError>.pipe()
				let signal = baseSignal |> take(2)

				var lastValue: Int?
				var completed = false
				signal.observe(
					next: { lastValue = $0 },
					completed: { completed = true }
				)

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sendNext(sink, 1)
				expect(lastValue).to(equal(1))
				expect(completed).to(beFalse())

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))
				expect(completed).to(beTrue())
			}

			it("should complete when 0") {
				let producer = SignalProducer<Int, NoError> { observer, disposable in
					sendNext(observer, 0)
				} |> take(0)

				var completed = false
				var valueSent = false

				expect(completed).to(beFalse())
				expect(valueSent).to(beFalse())

				producer.start(
					next: { _ in valueSent = true },
					completed: { completed = true }
				)

				expect(completed).to(beTrue())
				expect(valueSent).to(beFalse())
			}
		}

		describe("collect") {
			it("should collect all values") {
				let (original, sink) = Signal<Int, NoError>.pipe()
				let signal = original |> collect
				let expectedResult = [1, 2, 3]

				var result: [Int]?

				signal.observe(next: { value in
					expect(result).to(beNil())
					result = value
				})

				for number in expectedResult {
					sendNext(sink, number)
				}

				expect(result).to(beNil())
				sendCompleted(sink)
				expect(result).to(equal(expectedResult))
			}

			it("should complete with an empty array if there are no values") {
				let (original, sink) = Signal<Int, NoError>.pipe()
				let signal = original |> collect

				var result: [Int]?

				signal.observe(next: { result = $0 })

				expect(result).to(beNil())
				sendCompleted(sink)
				expect(result).to(equal([]))
			}

			it("should forward errors") {
				let (original, sink) = Signal<Int, TestError>.pipe()
				let signal = original |> collect

				var error: TestError?

				signal.observe(error: { error = $0 })

				expect(error).to(beNil())
				sendError(sink, .Default)
				expect(error).to(equal(TestError.Default))
			}
		}

		describe("takeUntil") {
			var signal: Signal<Int, NoError>!
			var sink: Signal<Int, NoError>.Observer!
			var triggerSink: Signal<(), NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let (triggerSignal, triggerObserver) = Signal<(), NoError>.pipe()

				signal = baseSignal |> takeUntil(triggerSignal)
				sink = observer
				triggerSink = triggerObserver

				lastValue = nil
				completed = false

				signal.observe(
					next: { lastValue = $0 },
					completed: { completed = true }
				)
			}

			it("should take values until the trigger fires") {
				expect(lastValue).to(beNil())

				sendNext(sink, 1)
				expect(lastValue).to(equal(1))

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))

				expect(completed).to(beFalse())
				sendNext(triggerSink, ())
				expect(completed).to(beTrue())
			}

			it("should complete if the trigger fires immediately") {
				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sendNext(triggerSink, ())

				expect(completed).to(beTrue())
				expect(lastValue).to(beNil())
			}
		}

		describe("takeUntilReplacement") {
			var signal: Signal<Int, NoError>!
			var sink: Signal<Int, NoError>.Observer!
			var replacementSink: Signal<Int, NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let (replacementSignal, replacementObserver) = Signal<Int, NoError>.pipe()

				signal = baseSignal |> takeUntilReplacement(replacementSignal)
				sink = observer
				replacementSink = replacementObserver

				lastValue = nil
				completed = false

				signal.observe(
					next: { lastValue = $0 },
					completed: { completed = true }
				)
			}

			it("should take values from the original then the replacement") {
				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sendNext(sink, 1)
				expect(lastValue).to(equal(1))

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))

				sendNext(replacementSink, 3)

				expect(lastValue).to(equal(3))
				expect(completed).to(beFalse())

				sendNext(sink, 4)

				expect(lastValue).to(equal(3))
				expect(completed).to(beFalse())

				sendNext(replacementSink, 5)
				expect(lastValue).to(equal(5))

				expect(completed).to(beFalse())
				sendCompleted(replacementSink)
				expect(completed).to(beTrue())
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
				var result: [String] = []
				var completed = false

				zipped.observe(next: { (left, right) in
					result.append("\(left)\(right)")
				}, completed: {
					completed = true
				})

				expect(completed).to(beFalsy())

				sendNext(leftSink, 0)
				sendCompleted(leftSink)
				expect(completed).to(beFalsy())
				expect(result).to(equal([]))

				sendNext(rightSink, "foo")
				expect(completed).to(beTruthy())
				expect(result).to(equal([ "0foo" ]))
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
			var testScheduler: TestScheduler!
			var signal: Signal<Int, TestError>!
			var sink: Signal<Int, TestError>.Observer!

			beforeEach {
				testScheduler = TestScheduler()
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				signal = baseSignal |> timeoutWithError(TestError.Default, afterInterval: 2, onScheduler: testScheduler)
				sink = observer
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				signal.observe(completed: {
					completed = true
				}, error: { _ in
					errored = true
				})

				testScheduler.scheduleAfter(1) {
					sendCompleted(sink)
				}

				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				testScheduler.run()
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}

			it("should error if not completed before the interval has elapsed") {
				var completed = false
				var errored = false
				signal.observe(completed: {
					completed = true
				}, error: { _ in
					errored = true
				})

				testScheduler.scheduleAfter(3) {
					sendCompleted(sink)
				}

				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				testScheduler.run()
				expect(completed).to(beFalsy())
				expect(errored).to(beTruthy())
			}
		}

		describe("try") {
			it("should forward original values upon success") {
				let (baseSignal, sink) = Signal<Int, TestError>.pipe()
				var signal = baseSignal |> try { _ in
					return success()
				}
				
				var current: Int?
				signal.observe(next: { value in
					current = value
				})
				
				for value in 1...5 {
					sendNext(sink, value)
					expect(current).to(equal(value))
				}
			}
			
			it("should error if an attempt fails") {
				let (baseSignal, sink) = Signal<Int, TestError>.pipe()
				var signal = baseSignal |> try { _ in
					return failure(.Default)
				}
				
				var error: TestError?
				signal.observe(error: { err in
					error = err
				})
				
				sendNext(sink, 42)
				expect(error).to(equal(TestError.Default))
			}
		}
		
		describe("tryMap") {
			it("should forward mapped values upon success") {
				let (baseSignal, sink) = Signal<Int, TestError>.pipe()
				var signal = baseSignal |> tryMap { num -> Result<Bool, TestError> in
					return success(num % 2 == 0)
				}
				
				var even: Bool?
				signal.observe(next: { value in
					even = value
				})
				
				sendNext(sink, 1)
				expect(even).to(equal(false))
				
				sendNext(sink, 2)
				expect(even).to(equal(true))
			}
			
			it("should error if a mapping fails") {
				let (baseSignal, sink) = Signal<Int, TestError>.pipe()
				var signal = baseSignal |> tryMap { _ -> Result<Bool, TestError> in
					return failure(.Default)
				}
				
				var error: TestError?
				signal.observe(error: { err in
					error = err
				})
				
				sendNext(sink, 42)
				expect(error).to(equal(TestError.Default))
			}
		}
	}
}
