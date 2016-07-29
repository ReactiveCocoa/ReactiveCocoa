//
//  SignalSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
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
				_ = Signal<AnyObject, NoError> { observer in
					didRunGenerator = true
				}
				
				expect(didRunGenerator) == true
			}

			it("should forward events to observers") {
				let numbers = [ 1, 2, 5 ]
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							observer.sendNext(number)
						}
						observer.sendCompleted()
					}
				}
				
				var fromSignal: [Int] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .next(number):
						fromSignal.append(number)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				expect(completed) == false
				expect(fromSignal).to(beEmpty())
				
				testScheduler.run()
				
				expect(completed) == true
				expect(fromSignal) == numbers
			}
		}

		describe("Signal.empty") {
			it("should interrupt its observers without emitting any value") {
				let signal = Signal<(), NoError>.empty

				var hasUnexpectedEventsEmitted = false
				var signalInterrupted = false

				signal.observe { event in
					switch event {
					case .next, .failed, .completed:
						hasUnexpectedEventsEmitted = true
					case .interrupted:
						signalInterrupted = true
					}
				}

				expect(hasUnexpectedEventsEmitted) == false
				expect(signalInterrupted) == true
			}
		}

		describe("Signal.pipe") {
			it("should forward events to observers") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				
				var fromSignal: [Int] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .next(number):
						fromSignal.append(number)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				expect(fromSignal).to(beEmpty())
				expect(completed) == false
				
				observer.sendNext(1)
				expect(fromSignal) == [ 1 ]
				
				observer.sendNext(2)
				expect(fromSignal) == [ 1, 2 ]
				
				expect(completed) == false
				observer.sendCompleted()
				expect(completed) == true
			}

			context("memory") {
				it("should not crash allocating memory with a few observers") {
					let (signal, _) = Signal<Int, NoError>.pipe()

					for _ in 0..<50 {
						autoreleasepool {
							let disposable = signal.observe { _ in }

							disposable!.dispose()
						}
					}
				}
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
					let observer = observer.on(terminated: disposable.dispose)
					testScheduler.schedule {
						for number in [ 1, 2 ] {
							observer.sendNext(number)
						}
						observer.sendCompleted()
						observer.sendNext(4)
					}
				}
				
				var fromSignal: [Int] = []
				signal.observeNext { number in
					fromSignal.append(number)
				}
				
				expect(disposable.isDisposed) == false
				expect(fromSignal).to(beEmpty())
				
				testScheduler.run()
				
				expect(disposable.isDisposed) == true
				expect(fromSignal) == [ 1, 2 ]
			}

			it("should not trigger side effects") {
				var runCount = 0
				let signal: Signal<(), NoError> = Signal { observer in
					runCount += 1
				}
				
				expect(runCount) == 1
				
				signal.observe(Observer<(), NoError>())
				expect(runCount) == 1
			}

			it("should release observer after termination") {
				weak var testStr: NSMutableString?
				let (signal, observer) = Signal<Int, NoError>.pipe()

				let test = {
					let innerStr: NSMutableString = NSMutableString()
					signal.observeNext { value in
						innerStr.append("\(value)")
					}
					testStr = innerStr
				}
				test()

				observer.sendNext(1)
				expect(testStr) == "1"
				observer.sendNext(2)
				expect(testStr) == "12"

				observer.sendCompleted()
				expect(testStr).to(beNil())
			}

			it("should release observer after interruption") {
				weak var testStr: NSMutableString?
				let (signal, observer) = Signal<Int, NoError>.pipe()

				let test = {
					let innerStr: NSMutableString = NSMutableString()
					signal.observeNext { value in
						innerStr.append("\(value)")
					}

					testStr = innerStr
				}

				test()

				observer.sendNext(1)
				expect(testStr) == "1"

				observer.sendNext(2)
				expect(testStr) == "12"

				observer.sendInterrupted()
				expect(testStr).to(beNil())
			}
		}

		describe("trailing closure") {
			it("receives next values") {
				var values = [Int]()
				let (signal, observer) = Signal<Int, NoError>.pipe()

				signal.observeNext { next in
					values.append(next)
				}

				observer.sendNext(1)
				expect(values) == [1]
			}

			it("receives results") {
				let (signal, observer) = Signal<Int, TestError>.pipe()

				var results: [Result<Int, TestError>] = []
				signal.observeResult { results.append($0) }

				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)
				observer.sendFailed(.default)

				observer.sendCompleted()

				expect(results).to(haveCount(4))
				expect(results[0].value) == 1
				expect(results[1].value) == 2
				expect(results[2].value) == 3
				expect(results[3].error) == .default
			}
		}

		describe("map") {
			it("should transform the values of the signal") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				let mappedSignal = signal.map { String($0 + 1) }

				var lastValue: String?

				mappedSignal.observeNext {
					lastValue = $0
					return
				}

				expect(lastValue).to(beNil())

				observer.sendNext(0)
				expect(lastValue) == "1"

				observer.sendNext(1)
				expect(lastValue) == "2"
			}
		}
		
		
		describe("mapError") {
			it("should transform the errors of the signal") {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 100, userInfo: nil)
				var error: NSError?

				signal
					.mapError { _ in producerError }
					.observeFailed { err in error = err }

				expect(error).to(beNil())

				observer.sendFailed(TestError.default)
				expect(error) == producerError
			}
		}

		describe("filter") {
			it("should omit values from the signal") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				let mappedSignal = signal.filter { $0 % 2 == 0 }

				var lastValue: Int?

				mappedSignal.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(0)
				expect(lastValue) == 0

				observer.sendNext(1)
				expect(lastValue) == 0

				observer.sendNext(2)
				expect(lastValue) == 2
			}
		}

		describe("ignoreNil") {
			it("should forward only non-nil values") {
				let (signal, observer) = Signal<Int?, NoError>.pipe()
				let mappedSignal = signal.ignoreNil()

				var lastValue: Int?

				mappedSignal.observeNext { lastValue = $0 }
				expect(lastValue).to(beNil())

				observer.sendNext(nil)
				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue) == 1

				observer.sendNext(nil)
				expect(lastValue) == 1

				observer.sendNext(2)
				expect(lastValue) == 2
			}
		}

		describe("scan") {
			it("should incrementally accumulate a value") {
				let (baseSignal, observer) = Signal<String, NoError>.pipe()
				let signal = baseSignal.scan("", +)

				var lastValue: String?

				signal.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext("a")
				expect(lastValue) == "a"

				observer.sendNext("bb")
				expect(lastValue) == "abb"
			}
		}

		describe("reduce") {
			it("should accumulate one value") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue).to(beNil())

				expect(completed) == false
				observer.sendCompleted()
				expect(completed) == true

				expect(lastValue) == 4
			}

			it("should send the initial value if none are received") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.sendCompleted()

				expect(lastValue) == 1
				expect(completed) == true
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.skip(first: 1)

				var lastValue: Int?
				signal.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue) == 2
			}

			it("should not skip any values when 0") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.skip(first: 0)

				var lastValue: Int?
				signal.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue) == 1

				observer.sendNext(2)
				expect(lastValue) == 2
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseSignal, observer) = Signal<Bool, NoError>.pipe()
				let signal = baseSignal.skipRepeats()

				var values: [Bool] = []
				signal.observeNext { values.append($0) }

				expect(values) == []

				observer.sendNext(true)
				expect(values) == [ true ]

				observer.sendNext(true)
				expect(values) == [ true ]

				observer.sendNext(false)
				expect(values) == [ true, false ]

				observer.sendNext(true)
				expect(values) == [ true, false, true ]
			}

			it("should skip values according to a predicate") {
				let (baseSignal, observer) = Signal<String, NoError>.pipe()
				let signal = baseSignal.skipRepeats { $0.characters.count == $1.characters.count }

				var values: [String] = []
				signal.observeNext { values.append($0) }

				expect(values) == []

				observer.sendNext("a")
				expect(values) == [ "a" ]

				observer.sendNext("b")
				expect(values) == [ "a" ]

				observer.sendNext("cc")
				expect(values) == [ "a", "cc" ]

				observer.sendNext("d")
				expect(values) == [ "a", "cc", "d" ]
			}

			it("should not store strong reference to previously passed items") {
				var disposedItems: [Bool] = []

				struct Item {
					let payload: Bool
					let disposable: ScopedDisposable
				}

				func item(_ payload: Bool) -> Item {
					return Item(
						payload: payload,
						disposable: ScopedDisposable(ActionDisposable { disposedItems.append(payload) })
					)
				}

				let (baseSignal, observer) = Signal<Item, NoError>.pipe()
				baseSignal.skipRepeats { $0.payload == $1.payload }.observeNext { _ in }

				observer.sendNext(item(true))
				expect(disposedItems) == []

				observer.sendNext(item(false))
				expect(disposedItems) == [ true ]

				observer.sendNext(item(false))
				expect(disposedItems) == [ true, false ]

				observer.sendNext(item(true))
				expect(disposedItems) == [ true, false, false ]

				observer.sendCompleted()
				expect(disposedItems) == [ true, false, false, true ]
			}
		}
		
		describe("uniqueValues") {
			it("should skip values that have been already seen") {
				let (baseSignal, observer) = Signal<String, NoError>.pipe()
				let signal = baseSignal.uniqueValues()
				
				var values: [String] = []
				signal.observeNext { values.append($0) }
				
				expect(values) == []

				observer.sendNext("a")
				expect(values) == [ "a" ]
				
				observer.sendNext("b")
				expect(values) == [ "a", "b" ]
				
				observer.sendNext("a")
				expect(values) == [ "a", "b" ]
				
				observer.sendNext("b")
				expect(values) == [ "a", "b" ]
				
				observer.sendNext("c")
				expect(values) == [ "a", "b", "c" ]
				
				observer.sendCompleted()
				expect(values) == [ "a", "b", "c" ]
			}
		}
		
		describe("skipWhile") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()

				signal = baseSignal.skip { $0 < 2 }
				observer = incomingObserver
				lastValue = nil

				signal.observeNext { lastValue = $0 }
			}

			it("should skip while the predicate is true") {
				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue) == 2

				observer.sendNext(0)
				expect(lastValue) == 0
			}

			it("should not skip any values when the predicate starts false") {
				expect(lastValue).to(beNil())

				observer.sendNext(3)
				expect(lastValue) == 3

				observer.sendNext(1)
				expect(lastValue) == 1
			}
		}
		
		describe("skipUntil") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var triggerObserver: Signal<(), NoError>.Observer!
			
			var lastValue: Int? = nil
			
			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (triggerSignal, incomingTriggerObserver) = Signal<(), NoError>.pipe()
				
				signal = baseSignal.skip(until: triggerSignal)
				observer = incomingObserver
				triggerObserver = incomingTriggerObserver
				
				lastValue = nil
				
				signal.observe { event in
					switch event {
					case let .next(value):
						lastValue = value
					default:
						break
					}
				}
			}
			
			it("should skip values until the trigger fires") {
				expect(lastValue).to(beNil())
				
				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue).to(beNil())

				triggerObserver.sendNext(())
				observer.sendNext(0)
				expect(lastValue) == 0
			}
			
			it("should skip values until the trigger completes") {
				expect(lastValue).to(beNil())
				
				observer.sendNext(1)
				expect(lastValue).to(beNil())
				
				observer.sendNext(2)
				expect(lastValue).to(beNil())
				
				triggerObserver.sendCompleted()
				observer.sendNext(0)
				expect(lastValue) == 0
			}
		}

		describe("take") {
			it("should take initial values") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.take(first: 2)

				var lastValue: Int?
				var completed = false
				signal.observe { event in
					switch event {
					case let .next(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.sendNext(1)
				expect(lastValue) == 1
				expect(completed) == false

				observer.sendNext(2)
				expect(lastValue) == 2
				expect(completed) == true
			}
			
			it("should complete immediately after taking given number of values") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()
				
				var signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							observer.sendNext(number)
						}
					}
				}
				
				var completed = false
				
				signal = signal.take(first: numbers.count)
				signal.observeCompleted { completed = true }
				
				expect(completed) == false
				testScheduler.run()
				expect(completed) == true
			}

			it("should interrupt when 0") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()

				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							observer.sendNext(number)
						}
					}
				}

				var result: [Int] = []
				var interrupted = false

				signal
				.take(first: 0)
				.observe { event in
					switch event {
					case let .next(number):
						result.append(number)
					case .interrupted:
						interrupted = true
					default:
						break
					}
				}

				expect(interrupted) == true

				testScheduler.run()
				expect(result).to(beEmpty())
			}
		}

		describe("collect") {
			it("should collect all values") {
				let (original, observer) = Signal<Int, NoError>.pipe()
				let signal = original.collect()
				let expectedResult = [ 1, 2, 3 ]

				var result: [Int]?

				signal.observeNext { value in
					expect(result).to(beNil())
					result = value
				}

				for number in expectedResult {
					observer.sendNext(number)
				}

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result) == expectedResult
			}

			it("should complete with an empty array if there are no values") {
				let (original, observer) = Signal<Int, NoError>.pipe()
				let signal = original.collect()

				var result: [Int]?

				signal.observeNext { result = $0 }

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result) == []
			}

			it("should forward errors") {
				let (original, observer) = Signal<Int, TestError>.pipe()
				let signal = original.collect()

				var error: TestError?

				signal.observeFailed { error = $0 }

				expect(error).to(beNil())
				observer.sendFailed(.default)
				expect(error) == TestError.default
			}

			it("should collect an exact count of values") {
				let (original, observer) = Signal<Int, NoError>.pipe()

				let signal = original.collect(count: 3)

				var observedValues: [[Int]] = []

				signal.observeNext { value in
					observedValues.append(value)
				}

				var expectation: [[Int]] = []

				for i in 1...7 {

					observer.sendNext(i)

					if i % 3 == 0 {
						expectation.append([Int]((i - 2)...i))
						expect(observedValues) == expectation
					} else {
						expect(observedValues) == expectation
					}
				}

				observer.sendCompleted()

				expectation.append([7])
				expect(observedValues) == expectation
			}

			it("should collect values until it matches a certain value") {
				let (original, observer) = Signal<Int, NoError>.pipe()

				let signal = original.collect { _, next in next != 5 }

				var expectedValues = [
					[5, 5],
					[42, 5]
				]

				signal.observeNext { value in
					expect(value) == expectedValues.removeFirst()
				}

				signal.observeCompleted {
					expect(expectedValues) == []
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.sendNext)

				observer.sendCompleted()
			}

			it("should collect values until it matches a certain condition on values") {
				let (original, observer) = Signal<Int, NoError>.pipe()

				let signal = original.collect { values in values.reduce(0, combine: +) == 10 }

				var expectedValues = [
					[1, 2, 3, 4],
					[5, 6, 7, 8, 9]
				]

				signal.observeNext { value in
					expect(value) == expectedValues.removeFirst()
				}

				signal.observeCompleted {
					expect(expectedValues) == []
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.sendNext)

				observer.sendCompleted()
			}
		}

		describe("takeUntil") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var triggerObserver: Signal<(), NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (triggerSignal, incomingTriggerObserver) = Signal<(), NoError>.pipe()

				signal = baseSignal.take(until: triggerSignal)
				observer = incomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil
				completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values until the trigger fires") {
				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue) == 1

				observer.sendNext(2)
				expect(lastValue) == 2

				expect(completed) == false
				triggerObserver.sendNext(())
				expect(completed) == true
			}
			
			it("should take values until the trigger completes") {
				expect(lastValue).to(beNil())
				
				observer.sendNext(1)
				expect(lastValue) == 1
				
				observer.sendNext(2)
				expect(lastValue) == 2
				
				expect(completed) == false
				triggerObserver.sendCompleted()
				expect(completed) == true
			}

			it("should complete if the trigger fires immediately") {
				expect(lastValue).to(beNil())
				expect(completed) == false

				triggerObserver.sendNext(())

				expect(completed) == true
				expect(lastValue).to(beNil())
			}
		}

		describe("takeUntilReplacement") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var replacementObserver: Signal<Int, NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (replacementSignal, incomingReplacementObserver) = Signal<Int, NoError>.pipe()

				signal = baseSignal.take(untilReplacement: replacementSignal)
				observer = incomingObserver
				replacementObserver = incomingReplacementObserver

				lastValue = nil
				completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values from the original then the replacement") {
				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.sendNext(1)
				expect(lastValue) == 1

				observer.sendNext(2)
				expect(lastValue) == 2

				replacementObserver.sendNext(3)

				expect(lastValue) == 3
				expect(completed) == false

				observer.sendNext(4)

				expect(lastValue) == 3
				expect(completed) == false

				replacementObserver.sendNext(5)
				expect(lastValue) == 5

				expect(completed) == false
				replacementObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("takeWhile") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()
				signal = baseSignal.take { $0 <= 4 }
				observer = incomingObserver
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						latestValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				for value in -1...4 {
					observer.sendNext(value)
					expect(latestValue) == value
					expect(completed) == false
				}

				observer.sendNext(5)
				expect(latestValue) == 4
				expect(completed) == true
			}

			it("should complete if the predicate starts false") {
				var latestValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						latestValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(5)
				expect(latestValue).to(beNil())
				expect(completed) == true
			}
		}

		describe("observeOn") {
			it("should send events on the given scheduler") {
				let testScheduler = TestScheduler()
				let (signal, observer) = Signal<Int, NoError>.pipe()
				
				var result: [Int] = []
				
				signal
					.observe(on: testScheduler)
					.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				expect(result).to(beEmpty())
				
				testScheduler.run()
				expect(result) == [ 1, 2 ]
			}
		}

		describe("delay") {
			it("should send events on the given scheduler after the interval") {
				let testScheduler = TestScheduler()
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						observer.sendNext(1)
					}
					testScheduler.schedule(after: 5) {
						observer.sendNext(2)
						observer.sendCompleted()
					}
				}
				
				var result: [Int] = []
				var completed = false
				
				signal
					.delay(10, on: testScheduler)
					.observe { event in
						switch event {
						case let .next(number):
							result.append(number)
						case .completed:
							completed = true
						default:
							break
						}
					}
				
				testScheduler.advance(by: 4) // send initial value
				expect(result).to(beEmpty())
				
				testScheduler.advance(by: 10) // send second value and receive first
				expect(result) == [ 1 ]
				expect(completed) == false
				
				testScheduler.advance(by: 10) // send second value and receive first
				expect(result) == [ 1, 2 ]
				expect(completed) == true
			}

			it("should schedule errors immediately") {
				let testScheduler = TestScheduler()
				let signal: Signal<Int, TestError> = Signal { observer in
					testScheduler.schedule {
						observer.sendFailed(TestError.default)
					}
				}
				
				var errored = false
				
				signal
					.delay(10, on: testScheduler)
					.observeFailed { _ in errored = true }
				
				testScheduler.advance()
				expect(errored) == true
			}
		}

		describe("throttle") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, NoError>.Observer!
			var signal: Signal<Int, NoError>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, NoError>.pipe()
				observer = baseObserver

				signal = baseSignal.throttle(1, on: scheduler)
				expect(signal).notTo(beNil())
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				signal.observeNext { value in
					values.append(value)
				}

				expect(values) == []

				observer.sendNext(0)
				expect(values) == []

				scheduler.advance()
				expect(values) == [ 0 ]

				observer.sendNext(1)
				observer.sendNext(2)
				expect(values) == [ 0 ]

				scheduler.advance(by: 1.5)
				expect(values) == [ 0, 2 ]

				scheduler.advance(by: 3)
				expect(values) == [ 0, 2 ]

				observer.sendNext(3)
				expect(values) == [ 0, 2 ]

				scheduler.advance()
				expect(values) == [ 0, 2, 3 ]

				observer.sendNext(4)
				observer.sendNext(5)
				scheduler.advance()
				expect(values) == [ 0, 2, 3 ]

				scheduler.run()
				expect(values) == [ 0, 2, 3, 5 ]
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(0)
				scheduler.advance()
				expect(values) == [ 0 ]

				observer.sendNext(1)
				observer.sendCompleted()
				expect(completed) == false

				scheduler.advance()
				expect(values) == [ 0 ]
				expect(completed) == true

				scheduler.run()
				expect(values) == [ 0 ]
				expect(completed) == true
			}
		}

		describe("debounce") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, NoError>.Observer!
			var signal: Signal<Int, NoError>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, NoError>.pipe()
				observer = baseObserver

				signal = baseSignal.debounce(1, on: scheduler)
				expect(signal).notTo(beNil())
			}

			it("should send values on the given scheduler once the interval has passed since the last value was sent") {
				var values: [Int] = []
				signal.observeNext { value in
					values.append(value)
				}

				expect(values) == []

				observer.sendNext(0)
				expect(values) == []

				scheduler.advance()
				expect(values) == []

				observer.sendNext(1)
				observer.sendNext(2)
				expect(values) == []

				scheduler.advance(by: 1.5)
				expect(values) == [ 2 ]

				scheduler.advance(by: 3)
				expect(values) == [ 2 ]

				observer.sendNext(3)
				expect(values) == [ 2 ]

				scheduler.advance()
				expect(values) == [ 2 ]

				observer.sendNext(4)
				observer.sendNext(5)
				scheduler.advance()
				expect(values) == [ 2 ]

				scheduler.run()
				expect(values) == [ 2, 5 ]
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .next(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(0)
				scheduler.advance()
				expect(values) == []

				observer.sendNext(1)
				observer.sendCompleted()
				expect(completed) == false

				scheduler.advance()
				expect(values) == []
				expect(completed) == true

				scheduler.run()
				expect(values) == []
				expect(completed) == true
			}
		}

		describe("sampleWith") {
			var sampledSignal: Signal<(Int, String), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<String, NoError>.Observer!
			
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (sampler, incomingSamplerObserver) = Signal<String, NoError>.pipe()
				sampledSignal = signal.sample(with: sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}

			it("should forward the latest value when the sampler fires") {
				var result: [String] = []
				sampledSignal.observeNext { (left, right) in result.append("\(left)\(right)") }
				
				observer.sendNext(1)
				observer.sendNext(2)
				samplerObserver.sendNext("a")
				expect(result) == [ "2a" ]
			}

			it("should do nothing if sampler fires before signal receives value") {
				var result: [String] = []
				sampledSignal.observeNext { (left, right) in result.append("\(left)\(right)") }
				
				samplerObserver.sendNext("a")
				expect(result).to(beEmpty())
			}

			it("should send lates value with sampler value multiple times when sampler fires multiple times") {
				var result: [String] = []
				sampledSignal.observeNext { (left, right) in result.append("\(left)\(right)") }
				
				observer.sendNext(1)
				samplerObserver.sendNext("a")
				samplerObserver.sendNext("b")
				expect(result) == [ "1a", "1b" ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledSignal.observeCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed) == false
				
				samplerObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("sampleOn") {
			var sampledSignal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<(), NoError>.Observer!
			
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (sampler, incomingSamplerObserver) = Signal<(), NoError>.pipe()
				sampledSignal = signal.sample(on: sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}
			
			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledSignal.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				samplerObserver.sendNext(())
				expect(result) == [ 2 ]
			}
			
			it("should do nothing if sampler fires before signal receives value") {
				var result: [Int] = []
				sampledSignal.observeNext { result.append($0) }
				
				samplerObserver.sendNext(())
				expect(result).to(beEmpty())
			}
			
			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [Int] = []
				sampledSignal.observeNext { result.append($0) }
				
				observer.sendNext(1)
				samplerObserver.sendNext(())
				samplerObserver.sendNext(())
				expect(result) == [ 1, 1 ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledSignal.observeCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed) == false
				
				samplerObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("combineLatestWith") {
			var combinedSignal: Signal<(Int, Double), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var otherObserver: Signal<Double, NoError>.Observer!
			
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (otherSignal, incomingOtherObserver) = Signal<Double, NoError>.pipe()
				combinedSignal = signal.combineLatest(with: otherSignal)
				observer = incomingObserver
				otherObserver = incomingOtherObserver
			}
			
			it("should forward the latest values from both inputs") {
				var latest: (Int, Double)?
				combinedSignal.observeNext { latest = $0 }
				
				observer.sendNext(1)
				expect(latest).to(beNil())
				
				// is there a better way to test tuples?
				otherObserver.sendNext(1.5)
				expect(latest?.0) == 1
				expect(latest?.1) == 1.5
				
				observer.sendNext(2)
				expect(latest?.0) == 2
				expect(latest?.1) == 1.5
			}

			it("should complete when both inputs have completed") {
				var completed = false
				combinedSignal.observeCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed) == false
				
				otherObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("zipWith") {
			var leftObserver: Signal<Int, NoError>.Observer!
			var rightObserver: Signal<String, NoError>.Observer!
			var zipped: Signal<(Int, String), NoError>!

			beforeEach {
				let (leftSignal, incomingLeftObserver) = Signal<Int, NoError>.pipe()
				let (rightSignal, incomingRightObserver) = Signal<String, NoError>.pipe()

				leftObserver = incomingLeftObserver
				rightObserver = incomingRightObserver
				zipped = leftSignal.zip(with: rightSignal)
			}

			it("should combine pairs") {
				var result: [String] = []
				zipped.observeNext { (left, right) in result.append("\(left)\(right)") }

				leftObserver.sendNext(1)
				leftObserver.sendNext(2)
				expect(result) == []

				rightObserver.sendNext("foo")
				expect(result) == [ "1foo" ]

				leftObserver.sendNext(3)
				rightObserver.sendNext("bar")
				expect(result) == [ "1foo", "2bar" ]

				rightObserver.sendNext("buzz")
				expect(result) == [ "1foo", "2bar", "3buzz" ]

				rightObserver.sendNext("fuzz")
				expect(result) == [ "1foo", "2bar", "3buzz" ]

				leftObserver.sendNext(4)
				expect(result) == [ "1foo", "2bar", "3buzz", "4fuzz" ]
			}

			it("should complete when the shorter signal has completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .next(left, right):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false

				leftObserver.sendNext(0)
				leftObserver.sendCompleted()
				expect(completed) == false
				expect(result) == []

				rightObserver.sendNext("foo")
				expect(completed) == true
				expect(result) == [ "0foo" ]
			}

			it("should complete when both signal have completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .next(left, right):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false

				leftObserver.sendNext(0)
				leftObserver.sendCompleted()
				expect(completed) == false
				expect(result) == []

				rightObserver.sendCompleted()
				expect(result) == [ ]
			}

			it("should complete and drop unpaired pending values when both signal have completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .next(left, right):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false

				leftObserver.sendNext(0)
				leftObserver.sendNext(1)
				leftObserver.sendNext(2)
				leftObserver.sendNext(3)
				leftObserver.sendCompleted()
				expect(completed) == false
				expect(result) == []

				rightObserver.sendNext("foo")
				rightObserver.sendNext("bar")
				rightObserver.sendCompleted()
				expect(result) == ["0foo", "1bar"]
			}
		}

		describe("materialize") {
			it("should reify events from the signal") {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				var latestEvent: Event<Int, TestError>?
				signal
					.materialize()
					.observeNext { latestEvent = $0 }
				
				observer.sendNext(2)
				
				expect(latestEvent).toNot(beNil())
				if let latestEvent = latestEvent {
					switch latestEvent {
					case let .next(value):
						expect(value) == 2
					default:
						fail()
					}
				}
				
				observer.sendFailed(TestError.default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .failed:
						()
					default:
						fail()
					}
				}
			}
		}

		describe("dematerialize") {
			typealias IntEvent = Event<Int, TestError>
			var observer: Signal<IntEvent, NoError>.Observer!
			var dematerialized: Signal<Int, TestError>!
			
			beforeEach {
				let (signal, incomingObserver) = Signal<IntEvent, NoError>.pipe()
				observer = incomingObserver
				dematerialized = signal.dematerialize()
			}
			
			it("should send values for Next events") {
				var result: [Int] = []
				dematerialized
					.assumeNoErrors()
					.observeNext { result.append($0) }
				
				expect(result).to(beEmpty())
				
				observer.sendNext(.next(2))
				expect(result) == [ 2 ]
				
				observer.sendNext(.next(4))
				expect(result) == [ 2, 4 ]
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.observeFailed { _ in errored = true }
				
				expect(errored) == false
				
				observer.sendNext(.failed(TestError.default))
				expect(errored) == true
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.observeCompleted { completed = true }
				
				expect(completed) == false
				observer.sendNext(IntEvent.completed)
				expect(completed) == true
			}
		}

		describe("takeLast") {
			var observer: Signal<Int, TestError>.Observer!
			var lastThree: Signal<Int, TestError>!
				
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, TestError>.pipe()
				observer = incomingObserver
				lastThree = signal.take(last: 3)
			}

			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree
					.assumeNoErrors()
					.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)
				observer.sendNext(4)
				expect(result).to(beEmpty())
				
				observer.sendCompleted()
				expect(result) == [ 2, 3, 4 ]
			}

			it("should send less than N values if not enough were received") {
				var result: [Int] = []
				lastThree
					.assumeNoErrors()
					.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendCompleted()
				expect(result) == [ 1, 2 ]
			}
			
			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.observe { event in
					switch event {
					case let .next(value):
						result.append(value)
					case .failed:
						errored = true
					default:
						break
					}
				}
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)
				expect(errored) == false
				
				observer.sendFailed(TestError.default)
				expect(errored) == true
				expect(result).to(beEmpty())
			}
		}

		describe("timeoutWithError") {
			var testScheduler: TestScheduler!
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			beforeEach {
				testScheduler = TestScheduler()
				let (baseSignal, incomingObserver) = Signal<Int, TestError>.pipe()
				signal = baseSignal.timeout(after: 2, raising: TestError.default, on: testScheduler)
				observer = incomingObserver
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				signal.observe { event in
					switch event {
					case .completed:
						completed = true
					case .failed:
						errored = true
					default:
						break
					}
				}

				testScheduler.schedule(after: 1) {
					observer.sendCompleted()
				}

				expect(completed) == false
				expect(errored) == false

				testScheduler.run()
				expect(completed) == true
				expect(errored) == false
			}

			it("should error if not completed before the interval has elapsed") {
				var completed = false
				var errored = false
				signal.observe { event in
					switch event {
					case .completed:
						completed = true
					case .failed:
						errored = true
					default:
						break
					}
				}

				testScheduler.schedule(after: 3) {
					observer.sendCompleted()
				}

				expect(completed) == false
				expect(errored) == false

				testScheduler.run()
				expect(completed) == false
				expect(errored) == true
			}
		}

		describe("attempt") {
			it("should forward original values upon success") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attempt { _ in
					return .success()
				}
				
				var current: Int?
				signal
					.assumeNoErrors()
					.observeNext { value in
						current = value
					}
				
				for value in 1...5 {
					observer.sendNext(value)
					expect(current) == value
				}
			}
			
			it("should error if an attempt fails") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attempt { _ in
					return .failure(.default)
				}
				
				var error: TestError?
				signal.observeFailed { err in
					error = err
				}
				
				observer.sendNext(42)
				expect(error) == TestError.default
			}
		}
		
		describe("attemptMap") {
			it("should forward mapped values upon success") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attemptMap { num -> Result<Bool, TestError> in
					return .success(num % 2 == 0)
				}
				
				var even: Bool?
				signal
					.assumeNoErrors()
					.observeNext { value in
						even = value
					}
				
				observer.sendNext(1)
				expect(even) == false
				
				observer.sendNext(2)
				expect(even) == true
			}
			
			it("should error if a mapping fails") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attemptMap { _ -> Result<Bool, TestError> in
					return .failure(.default)
				}
				
				var error: TestError?
				signal.observeFailed { err in
					error = err
				}
				
				observer.sendNext(42)
				expect(error) == TestError.default
			}
		}
		
		describe("combinePrevious") {
			var observer: Signal<Int, NoError>.Observer!
			let initialValue: Int = 0
			var latestValues: (Int, Int)?
			
			beforeEach {
				latestValues = nil
				
				let (signal, baseObserver) = Signal<Int, NoError>.pipe()
				observer = baseObserver
				signal.combinePrevious(initialValue).observeNext { latestValues = $0 }
			}
			
			it("should forward the latest value with previous value") {
				expect(latestValues).to(beNil())
				
				observer.sendNext(1)
				expect(latestValues?.0) == initialValue
				expect(latestValues?.1) == 1
				
				observer.sendNext(2)
				expect(latestValues?.0) == 1
				expect(latestValues?.1) == 2
			}
		}

		describe("combineLatest") {
			var signalA: Signal<Int, NoError>!
			var signalB: Signal<Int, NoError>!
			var signalC: Signal<Int, NoError>!
			var observerA: Signal<Int, NoError>.Observer!
			var observerB: Signal<Int, NoError>.Observer!
			var observerC: Signal<Int, NoError>.Observer!
			
			var combinedValues: [Int]?
			var completed: Bool!
			
			beforeEach {
				combinedValues = nil
				completed = false
				
				let (baseSignalA, baseObserverA) = Signal<Int, NoError>.pipe()
				let (baseSignalB, baseObserverB) = Signal<Int, NoError>.pipe()
				let (baseSignalC, baseObserverC) = Signal<Int, NoError>.pipe()
				
				signalA = baseSignalA
				signalB = baseSignalB
				signalC = baseSignalC
				
				observerA = baseObserverA
				observerB = baseObserverB
				observerC = baseObserverC
			}
			
			let combineLatestExampleName = "combineLatest examples"
			sharedExamples(combineLatestExampleName) {
				it("should forward the latest values from all inputs"){
					expect(combinedValues).to(beNil())
					
					observerA.sendNext(0)
					observerB.sendNext(1)
					observerC.sendNext(2)
					expect(combinedValues) == [0, 1, 2]
					
					observerA.sendNext(10)
					expect(combinedValues) == [10, 1, 2]
				}
				
				it("should not forward the latest values before all inputs"){
					expect(combinedValues).to(beNil())
					
					observerA.sendNext(0)
					expect(combinedValues).to(beNil())
					
					observerB.sendNext(1)
					expect(combinedValues).to(beNil())
					
					observerC.sendNext(2)
					expect(combinedValues) == [0, 1, 2]
				}
				
				it("should complete when all inputs have completed"){
					expect(completed) == false
					
					observerA.sendCompleted()
					observerB.sendCompleted()
					expect(completed) == false
					
					observerC.sendCompleted()
					expect(completed) == true
				}
			}
			
			describe("tuple") {
				beforeEach {
					Signal.combineLatest(signalA, signalB, signalC)
						.observe { event in
							switch event {
							case let .next(value):
								combinedValues = [value.0, value.1, value.2]
							case .completed:
								completed = true
							default:
								break
							}
						}
				}
				
				itBehavesLike(combineLatestExampleName)
			}
			
			describe("sequence") {
				beforeEach {
					Signal.combineLatest([signalA, signalB, signalC])
					.observe { event in
						switch event {
						case let .next(values):
							combinedValues = values
						case .completed:
							completed = true
						default:
							break
						}
					}
				}
				
				itBehavesLike(combineLatestExampleName)
			}
		}
		
		describe("zip") {
			var signalA: Signal<Int, NoError>!
			var signalB: Signal<Int, NoError>!
			var signalC: Signal<Int, NoError>!
			var observerA: Signal<Int, NoError>.Observer!
			var observerB: Signal<Int, NoError>.Observer!
			var observerC: Signal<Int, NoError>.Observer!

			var zippedValues: [Int]?
			var completed: Bool!
            
			beforeEach {
				zippedValues = nil
				completed = false
                
				let (baseSignalA, baseObserverA) = Signal<Int, NoError>.pipe()
				let (baseSignalB, baseObserverB) = Signal<Int, NoError>.pipe()
				let (baseSignalC, baseObserverC) = Signal<Int, NoError>.pipe()
				
				signalA = baseSignalA
				signalB = baseSignalB
				signalC = baseSignalC
				
				observerA = baseObserverA
				observerB = baseObserverB
				observerC = baseObserverC
			}
			
			let zipExampleName = "zip examples"
			sharedExamples(zipExampleName) {
				it("should combine all set"){
					expect(zippedValues).to(beNil())
					
					observerA.sendNext(0)
					expect(zippedValues).to(beNil())
					
					observerB.sendNext(1)
					expect(zippedValues).to(beNil())
					
					observerC.sendNext(2)
					expect(zippedValues) == [0, 1, 2]
					
					observerA.sendNext(10)
					expect(zippedValues) == [0, 1, 2]
					
					observerA.sendNext(20)
					expect(zippedValues) == [0, 1, 2]
					
					observerB.sendNext(11)
					expect(zippedValues) == [0, 1, 2]
					
					observerC.sendNext(12)
					expect(zippedValues) == [10, 11, 12]
				}
				
				it("should complete when the shorter signal has completed"){
					expect(completed) == false
					
					observerB.sendNext(1)
					observerC.sendNext(2)
					observerB.sendCompleted()
					observerC.sendCompleted()
					expect(completed) == false
					
					observerA.sendNext(0)
					expect(completed) == true
				}
			}
			
			describe("tuple") {
				beforeEach {
					Signal.zip(signalA, signalB, signalC)
						.observe { event in
							switch event {
							case let .next(value):
								zippedValues = [value.0, value.1, value.2]
							case .completed:
								completed = true
							default:
								break
							}
						}
				}
				
				itBehavesLike(zipExampleName)
			}
			
			describe("sequence") {
				beforeEach {
					Signal.zip([signalA, signalB, signalC])
						.observe { event in
							switch event {
							case let .next(values):
								zippedValues = values
							case .completed:
								completed = true
							default:
								break
							}
						}
				}
				
				itBehavesLike(zipExampleName)
			}
			
			describe("log events") {
				it("should output the correct event without identifier") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event) == "[] next 1" },
						{ event in expect(event) == "[] completed" },
						{ event in expect(event) == "[] terminated" },
						{ event in expect(event) == "[] disposed" },
					]

					let logger = TestLogger(expectations: expectations)
					
					let (signal, observer) = Signal<Int, NoError>.pipe()
					signal
						.logEvents(logger: logger.logEvent)
						.observe { _ in }
					
					observer.sendNext(1)
					observer.sendCompleted()
				}
				
				it("should output the correct event with identifier") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event) == "[test.rac] next 1" },
						{ event in expect(event) == "[test.rac] failed error1" },
						{ event in expect(event) == "[test.rac] terminated" },
						{ event in expect(event) == "[test.rac] disposed" },
					]

					let logger = TestLogger(expectations: expectations)

					let (signal, observer) = Signal<Int, TestError>.pipe()
					signal
						.logEvents(identifier: "test.rac", logger: logger.logEvent)
						.observe { _ in }
					
					observer.sendNext(1)
					observer.sendFailed(.error1)
				}
				
				it("should only output the events specified in the `events` parameter") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event) == "[test.rac] failed error1" },
					]
					
					let logger = TestLogger(expectations: expectations)
					
					let (signal, observer) = Signal<Int, TestError>.pipe()
					signal
						.logEvents(identifier: "test.rac", events: [.failed], logger: logger.logEvent)
						.observe { _ in }
					
					observer.sendNext(1)
					observer.sendFailed(.error1)
				}
			}
		}
	}
}
