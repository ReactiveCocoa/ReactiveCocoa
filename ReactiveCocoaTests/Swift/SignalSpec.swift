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

			it("should not keep signal alive indefinitely") {
				weak var signal: Signal<AnyObject, NoError>? = Signal.never
				
				expect(signal).to(beNil())
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

			it("should deallocate after interrupting") {
				weak var signal: Signal<AnyObject, NoError>? = Signal { observer in
					testScheduler.schedule {
						sendInterrupted(observer)
					}

					return nil
				}

				var interrupted = false
				signal?.observe(interrupted: { interrupted = true })

				expect(interrupted).to(beFalsy())
				expect(signal).toNot(beNil())

				testScheduler.run()

				expect(interrupted).to(beTruthy())
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

			it("should dispose of returned disposable upon interrupted") {
				let disposable = SimpleDisposable()

				let signal: Signal<AnyObject, NoError> = Signal { observer in
					testScheduler.schedule {
						sendInterrupted(observer)
					}
					return disposable
				}

				var interrupted = false
				signal.observe(interrupted: { interrupted = true })

				expect(interrupted).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())

				testScheduler.run()

				expect(interrupted).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}
		}

		describe("Signal.pipe") {
			it("should not keep signal alive indefinitely") {
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
						sendError(observer, TestError.Default)
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
						sendCompleted(observer)
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
						sendInterrupted(observer)
					}
				}

				test()
				expect(weakSignal).toNot(beNil())

				testScheduler.run()
				expect(weakSignal).to(beNil())
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
				expect(fromSignal).to(equal([ 1 ]))
				
				sendNext(observer, 2)
				expect(fromSignal).to(equal([ 1, 2 ]))
				
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
						for number in [ 1, 2 ] {
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
				expect(fromSignal).to(equal([ 1, 2 ]))
			}

			it("should not trigger side effects") {
				var runCount = 0
				let signal: Signal<(), NoError> = Signal { observer in
					runCount += 1
					return nil
				}
				
				expect(runCount).to(equal(1))
				
				signal.observe()
				expect(runCount).to(equal(1))
			}

			it("should release observer after termination") {
				weak var testStr: NSMutableString?
				let (signal, sink) = Signal<Int, NoError>.pipe()

				let test: () -> () = {
					var innerStr: NSMutableString = NSMutableString()
					signal.observe(next: { value in
						innerStr.appendString("\(value)")
					})
					testStr = innerStr
				}
				test()

				sendNext(sink, 1)
				expect(testStr).to(equal("1"))
				sendNext(sink, 2)
				expect(testStr).to(equal("12"))

				sendCompleted(sink)
				expect(testStr).to(beNil())
			}

			it("should release observer after interruption") {
				weak var testStr: NSMutableString?
				let (signal, sink) = Signal<Int, NoError>.pipe()

				let test: () -> () = {
					var innerStr: NSMutableString = NSMutableString()
					signal.observe(next: { value in
						innerStr.appendString("\(value)")
					})

					testStr = innerStr
				}

				test()

				sendNext(sink, 1)
				expect(testStr).to(equal("1"))

				sendNext(sink, 2)
				expect(testStr).to(equal("12"))

				sendInterrupted(sink)
				expect(testStr).to(beNil())
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
				expect(values).to(equal([ true ]))

				sendNext(sink, true)
				expect(values).to(equal([ true ]))

				sendNext(sink, false)
				expect(values).to(equal([ true, false ]))

				sendNext(sink, true)
				expect(values).to(equal([ true, false, true ]))
			}

			it("should skip values according to a predicate") {
				let (baseSignal, sink) = Signal<String, NoError>.pipe()
				let signal = baseSignal |> skipRepeats { countElements($0) == countElements($1) }

				var values: [String] = []
				signal.observe(next: { values.append($0) })

				expect(values).to(equal([]))

				sendNext(sink, "a")
				expect(values).to(equal([ "a" ]))

				sendNext(sink, "b")
				expect(values).to(equal([ "a" ]))

				sendNext(sink, "cc")
				expect(values).to(equal([ "a", "cc" ]))

				sendNext(sink, "d")
				expect(values).to(equal([ "a", "cc", "d" ]))
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
				signal.observe(next: {
					lastValue = $0
				}, completed: {
					completed = true
				})

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				sendNext(sink, 1)
				expect(lastValue).to(equal(1))
				expect(completed).to(beFalse())

				sendNext(sink, 2)
				expect(lastValue).to(equal(2))
				expect(completed).to(beTrue())
			}
			
			it("should complete immediately after taking given number of values") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				var testScheduler = TestScheduler()
				
				var signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
					}
					return nil
				}
				
				var completed = false
				
				signal = signal |> take(numbers.count)
				signal.observe(completed: { completed = true })
				
				expect(completed).to(beFalsy())
				testScheduler.run()
				expect(completed).to(beTruthy())
			}

			it("should interrupt when 0") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				var testScheduler = TestScheduler()

				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
					}
					return nil
				}

				var result: [Int] = []
				var interrupted = false

				signal
				|> take(0)
				|> observe(next: { number in
					result.append(number)
				}, interrupted: {
					interrupted = true
				})

				expect(interrupted).to(beTruthy())

				testScheduler.run()
				expect(result).to(beEmpty())
			}
		}

		describe("collect") {
			it("should collect all values") {
				let (original, sink) = Signal<Int, NoError>.pipe()
				let signal = original |> collect
				let expectedResult = [ 1, 2, 3 ]

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
			it("should send events on the given scheduler") {
				let testScheduler = TestScheduler()
				let (signal, observer) = Signal<Int, NoError>.pipe()
				
				var result: [Int] = []
				
				signal
				|> observeOn(testScheduler)
				|> observe(next: { result.append($0) })
				
				sendNext(observer, 1)
				sendNext(observer, 2)
				expect(result).to(beEmpty())
				
				testScheduler.run()
				expect(result).to(equal([ 1, 2 ]))
			}
		}

		describe("delay") {
			it("should send events on the given scheduler after the interval") {
				let testScheduler = TestScheduler()
				var signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						sendNext(observer, 1)
					}
					testScheduler.scheduleAfter(5, {
						sendNext(observer, 2)
						sendCompleted(observer)
					})
					return nil
				}
				
				var result: [Int] = []
				var completed = false
				
				signal
				|> delay(10, onScheduler: testScheduler)
				|> observe(next: { number in
						result.append(number)
					}, completed: {
						completed = true
					})
				
				testScheduler.advanceByInterval(4) // send initial value
				expect(result).to(beEmpty())
				
				testScheduler.advanceByInterval(10) // send second value and receive first
				expect(result).to(equal([ 1 ]))
				expect(completed).to(beFalsy())
				
				testScheduler.advanceByInterval(10) // send second value and receive first
				expect(result).to(equal([ 1, 2 ]))
				expect(completed).to(beTruthy())
			}

			it("should schedule errors immediately") {
				let testScheduler = TestScheduler()
				var signal: Signal<Int, TestError> = Signal { observer in
					testScheduler.schedule {
						sendError(observer, TestError.Default)
					}
					return nil
				}
				
				var errored = false
				
				signal
				|> delay(10, onScheduler: testScheduler)
				|> observe(error: { _ in errored = true })
				
				testScheduler.advance()
				expect(errored).to(beTruthy())
			}
		}

		describe("throttle") {
			pending("should send values on the given scheduler at no less than the interval") {
			}

			pending("should schedule errors immediately") {
			}
		}

		describe("sampleOn") {
			var sampledSignal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<(), NoError>.Observer!
			
			beforeEach {
				let (signal, sink) = Signal<Int, NoError>.pipe()
				let (sampler, samplesSink) = Signal<(), NoError>.pipe()
				sampledSignal = signal |> sampleOn(sampler)
				observer = sink
				samplerObserver = samplesSink
			}
			
			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledSignal.observe(next: { result.append($0) })
				
				sendNext(observer, 1)
				sendNext(observer, 2)
				sendNext(samplerObserver, ())
				expect(result).to(equal([ 2 ]))
			}
			
			it("should do nothing if sampler fires before signal receives value") {
				var result: [Int] = []
				sampledSignal.observe(next: { result.append($0) })
				
				sendNext(samplerObserver, ())
				expect(result).to(beEmpty())
			}
			
			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [Int] = []
				sampledSignal.observe(next: { result.append($0) })
				
				sendNext(observer, 1)
				sendNext(samplerObserver, ())
				sendNext(samplerObserver, ())
				expect(result).to(equal([ 1, 1 ]))
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledSignal.observe(completed: { completed = true })
				
				sendCompleted(observer)
				expect(completed).to(beFalsy())
				
				sendCompleted(samplerObserver)
				expect(completed).to(beTruthy())
			}
		}

		describe("combineLatestWith") {
			var combinedSignal: Signal<(Int, Double), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var otherObserver: Signal<Double, NoError>.Observer!
			
			beforeEach {
				let (signal, sink) = Signal<Int, NoError>.pipe()
				let (otherSignal, otherSink) = Signal<Double, NoError>.pipe()
				combinedSignal = signal |> combineLatestWith(otherSignal)
				observer = sink
				otherObserver = otherSink
			}
			
			it("should forward the latest values from both inputs") {
				var latest: (Int, Double)?
				combinedSignal.observe(next: { latest = $0 })
				
				sendNext(observer, 1)
				expect(latest).to(beNil())
				
				// is there a better way to test tuples?
				sendNext(otherObserver, 1.5)
				expect(latest?.0).to(equal(1))
				expect(latest?.1).to(equal(1.5))
				
				sendNext(observer, 2)
				expect(latest?.0).to(equal(2))
				expect(latest?.1).to(equal(1.5))
			}

			it("should complete when both inputs have completed") {
				var completed = false
				combinedSignal.observe(completed: { completed = true })
				
				sendCompleted(observer)
				expect(completed).to(beFalsy())
				
				sendCompleted(otherObserver)
				expect(completed).to(beTruthy())
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
			it("should reify events from the signal") {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				var latestEvent: Event<Int, TestError>?
				signal
				|> materialize
				|> observe(next: { latestEvent = $0 })
				
				sendNext(observer, 2)
				
				expect(latestEvent).toNot(beNil())
				if let latestEvent = latestEvent {
					switch latestEvent {
					case let .Next(box):
						expect(box.unbox).to(equal(2))
					default:
						fail()
					}
				}
				
				sendError(observer, TestError.Default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .Error(_):
						()
					default:
						fail()
					}
				}
			}
		}

		describe("dematerialize") {
			typealias IntEvent = Event<Int, TestError>
			var sink: Signal<IntEvent, NoError>.Observer!
			var dematerialized: Signal<Int, TestError>!
			
			beforeEach {
				let (signal, observer) = Signal<IntEvent, NoError>.pipe()
				sink = observer
				dematerialized = signal |> dematerialize
			}
			
			it("should send values for Next events") {
				var result: [Int] = []
				dematerialized.observe(next: { result.append($0) })
				
				expect(result).to(beEmpty())
				
				sendNext(sink, IntEvent.Next(Box(2)))
				expect(result).to(equal([ 2 ]))
				
				sendNext(sink, IntEvent.Next(Box(4)))
				expect(result).to(equal([ 2, 4 ]))
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.observe(error: { _ in errored = true })
				
				expect(errored).to(beFalsy())
				
				sendNext(sink, IntEvent.Error(Box(TestError.Default)))
				expect(errored).to(beTruthy())
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.observe(completed: { completed = true })
				
				expect(completed).to(beFalsy())
				sendNext(sink, IntEvent.Completed)
				expect(completed).to(beTruthy())
			}
		}

		describe("takeLast") {
			var sink: Signal<Int, TestError>.Observer!
			var lastThree: Signal<Int, TestError>!
				
			beforeEach {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				sink = observer
				lastThree = signal |> takeLast(3)
			}
			
			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree.observe(next: { result.append($0) })
				
				sendNext(sink, 1)
				sendNext(sink, 2)
				sendNext(sink, 3)
				sendNext(sink, 4)
				expect(result).to(beEmpty())
				
				sendCompleted(sink)
				expect(result).to(equal([ 2, 3, 4 ]))
			}

			it("should send less than N values if not enough were received") {
				var result: [Int] = []
				lastThree.observe(next: { result.append($0) })
				
				sendNext(sink, 1)
				sendNext(sink, 2)
				sendCompleted(sink)
				expect(result).to(equal([ 1, 2 ]))
			}
			
			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.observe(	next: { result.append($0) },
									error: { _ in errored = true }	)
				
				sendNext(sink, 1)
				sendNext(sink, 2)
				sendNext(sink, 3)
				expect(errored).to(beFalsy())
				
				sendError(sink, TestError.Default)
				expect(errored).to(beTruthy())
				expect(result).to(beEmpty())
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
