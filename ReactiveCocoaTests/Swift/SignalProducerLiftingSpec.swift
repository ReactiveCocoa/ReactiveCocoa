//
//  SignalProducerLiftingSpec.swift
//  ReactiveCocoa
//
//  Created by Neil Pankey on 6/14/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

class SignalProducerLiftingSpec: QuickSpec {
	override func spec() {
		describe("map") {
			it("should transform the values of the signal") {
				let (producer, observer) = SignalProducer<Int, NoError>.pipe()
				let mappedProducer = producer.map { String($0 + 1) }

				var lastValue: String?

				mappedProducer.startWithNext {
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
				let (producer, observer) = SignalProducer<Int, TestError>.pipe()
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 100, userInfo: nil)
				var error: NSError?

				producer
					.mapError { _ in producerError }
					.startWithFailed { error = $0 }

				expect(error).to(beNil())

				observer.sendFailed(TestError.Default)
				expect(error) == producerError
			}
		}

		describe("filter") {
			it("should omit values from the producer") {
				let (producer, observer) = SignalProducer<Int, NoError>.pipe()
				let mappedProducer = producer.filter { $0 % 2 == 0 }

				var lastValue: Int?

				mappedProducer.startWithNext { lastValue = $0 }

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
				let (producer, observer) = SignalProducer<Int?, NoError>.pipe()
				let mappedProducer = producer.ignoreNil()

				var lastValue: Int?

				mappedProducer.startWithNext { lastValue = $0 }
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
				let (baseProducer, observer) = SignalProducer<String, NoError>.pipe()
				let producer = baseProducer.scan("", +)

				var lastValue: String?

				producer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext("a")
				expect(lastValue) == "a"

				observer.sendNext("bb")
				expect(lastValue) == "abb"
			}
		}

		describe("reduce") {
			it("should accumulate one value") {
				let (baseProducer, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = baseProducer.reduce(1, +)

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = baseProducer.reduce(1, +)

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = baseProducer.skip(1)

				var lastValue: Int?
				producer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue) == 2
			}

			it("should not skip any values when 0") {
				let (baseProducer, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = baseProducer.skip(0)

				var lastValue: Int?
				producer.startWithNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue) == 1

				observer.sendNext(2)
				expect(lastValue) == 2
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseProducer, observer) = SignalProducer<Bool, NoError>.pipe()
				let producer = baseProducer.skipRepeats()

				var values: [Bool] = []
				producer.startWithNext { values.append($0) }

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
				let (baseProducer, observer) = SignalProducer<String, NoError>.pipe()
				let producer = baseProducer.skipRepeats { $0.characters.count == $1.characters.count }

				var values: [String] = []
				producer.startWithNext { values.append($0) }

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
		}

		describe("skipWhile") {
			var producer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, NoError>.pipe()

				producer = baseProducer.skipWhile { $0 < 2 }
				observer = incomingObserver
				lastValue = nil

				producer.startWithNext { lastValue = $0 }
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
			var producer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var triggerObserver: Signal<(), NoError>.Observer!
			
			var lastValue: Int? = nil
			
			beforeEach {
				let (baseProducer, baseIncomingObserver) = SignalProducer<Int, NoError>.pipe()
				let (triggerProducer, incomingTriggerObserver) = SignalProducer<(), NoError>.pipe()

				producer = baseProducer.skipUntil(triggerProducer)
				observer = baseIncomingObserver
				triggerObserver = incomingTriggerObserver
				
				lastValue = nil
				
				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Failed, .Completed, .Interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = baseProducer.take(2)

				var lastValue: Int?
				var completed = false
				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
				
				let producer: SignalProducer<Int, NoError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let observer = observer

					testScheduler.schedule {
						for number in numbers {
							observer.sendNext(number)
						}
					}
				}
				
				var completed = false
				
				producer
					.take(numbers.count)
					.startWithCompleted { completed = true }
				
				expect(completed) == false
				testScheduler.run()
				expect(completed) == true
			}

			it("should interrupt when 0") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()

				let producer: SignalProducer<Int, NoError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let observer = observer

					testScheduler.schedule {
						for number in numbers {
							observer.sendNext(number)
						}
					}
				}

				var result: [Int] = []
				var interrupted = false

				producer
				.take(0)
				.start { event in
					switch event {
					case let .Next(number):
						result.append(number)
					case .Interrupted:
						interrupted = true
					case .Failed, .Completed:
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
				let (original, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = original.collect()
				let expectedResult = [ 1, 2, 3 ]

				var result: [Int]?

				producer.startWithNext { value in
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
				let (original, observer) = SignalProducer<Int, NoError>.pipe()
				let producer = original.collect()

				var result: [Int]?

				producer.startWithNext { result = $0 }

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result) == []
			}

			it("should forward errors") {
				let (original, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = original.collect()

				var error: TestError?

				producer.startWithFailed { error = $0 }

				expect(error).to(beNil())
				observer.sendFailed(.Default)
				expect(error) == TestError.Default
			}

			it("should collect an exact count of values") {
				let (original, observer) = SignalProducer<Int, NoError>.pipe()

				let producer = original.collect(count: 3)

				var observedValues: [[Int]] = []

				producer.startWithNext { value in
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
				let (original, observer) = SignalProducer<Int, NoError>.pipe()

				let producer = original.collect { _, next in next != 5 }

				var expectedValues = [
					[5, 5],
					[42, 5]
				]

				producer.startWithNext { value in
					expect(value) == expectedValues.removeFirst()
				}

				producer.startWithCompleted {
					expect(expectedValues) == []
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.sendNext)

				observer.sendCompleted()
			}

			it("should collect values until it matches a certain condition on values") {
				let (original, observer) = SignalProducer<Int, NoError>.pipe()

				let producer = original.collect { values in values.reduce(0, combine: +) == 10 }

				var expectedValues = [
					[1, 2, 3, 4],
					[5, 6, 7, 8, 9]
				]

				producer.startWithNext { value in
					expect(value) == expectedValues.removeFirst()
				}

				producer.startWithCompleted {
					expect(expectedValues) == []
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.sendNext)
				
				observer.sendCompleted()
			}
			
		}

		describe("takeUntil") {
			var producer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var triggerObserver: Signal<(), NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseProducer, baseIncomingObserver) = SignalProducer<Int, NoError>.pipe()
				let (triggerProducer, incomingTriggerObserver) = SignalProducer<(), NoError>.pipe()

				producer = baseProducer.takeUntil(triggerProducer)
				observer = baseIncomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil
				completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
			var producer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var replacementObserver: Signal<Int, NoError>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, NoError>.pipe()
				let (replacementProducer, incomingReplacementObserver) = SignalProducer<Int, NoError>.pipe()

				producer = baseProducer.takeUntilReplacement(replacementProducer)
				observer = incomingObserver
				replacementObserver = incomingReplacementObserver

				lastValue = nil
				completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
			var producer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, NoError>.pipe()
				producer = baseProducer.takeWhile { $0 <= 4 }
				observer = incomingObserver
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				producer.start { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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

				producer.start { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
				let (producer, observer) = SignalProducer<Int, NoError>.pipe()

				var result: [Int] = []

				producer
					.observeOn(testScheduler)
					.startWithNext { result.append($0) }
				
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
				let producer: SignalProducer<Int, NoError> = SignalProducer { observer, _ in
					testScheduler.schedule {
						observer.sendNext(1)
					}
					testScheduler.scheduleAfter(5, action: {
						observer.sendNext(2)
						observer.sendCompleted()
					})
				}
				
				var result: [Int] = []
				var completed = false
				
				producer
					.delay(10, onScheduler: testScheduler)
					.start { event in
						switch event {
						case let .Next(number):
							result.append(number)
						case .Completed:
							completed = true
						case .Failed, .Interrupted:
							break
						}
					}
				
				testScheduler.advanceByInterval(4) // send initial value
				expect(result).to(beEmpty())
				
				testScheduler.advanceByInterval(10) // send second value and receive first
				expect(result) == [ 1 ]
				expect(completed) == false
				
				testScheduler.advanceByInterval(10) // send second value and receive first
				expect(result) == [ 1, 2 ]
				expect(completed) == true
			}

			it("should schedule errors immediately") {
				let testScheduler = TestScheduler()
				let producer: SignalProducer<Int, TestError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let observer = observer

					testScheduler.schedule {
						observer.sendFailed(TestError.Default)
					}
				}
				
				var errored = false
				
				producer
					.delay(10, onScheduler: testScheduler)
					.startWithFailed { _ in errored = true }
				
				testScheduler.advance()
				expect(errored) == true
			}
		}

		describe("throttle") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, NoError>.Observer!
			var producer: SignalProducer<Int, NoError>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseProducer, baseObserver) = SignalProducer<Int, NoError>.pipe()
				observer = baseObserver

				producer = baseProducer.throttle(1, onScheduler: scheduler)
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				producer.startWithNext { value in
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

				scheduler.advanceByInterval(1.5)
				expect(values) == [ 0, 2 ]

				scheduler.advanceByInterval(3)
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

				producer.start { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
						break
					}
				}

				observer.sendNext(0)
				scheduler.advance()
				expect(values) == [ 0 ]

				observer.sendNext(1)
				observer.sendCompleted()
				expect(completed) == false

				scheduler.run()
				expect(values) == [ 0 ]
				expect(completed) == true
			}
		}

		describe("sampleWith") {
			var sampledProducer: SignalProducer<(Int, String), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<String, NoError>.Observer!
			
			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, NoError>.pipe()
				let (sampler, incomingSamplerObserver) = SignalProducer<String, NoError>.pipe()
				sampledProducer = producer.sampleWith(sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}
			
			it("should forward the latest value when the sampler fires") {
				var result: [String] = []
				sampledProducer.startWithNext { (left, right) in result.append("\(left)\(right)") }
				
				observer.sendNext(1)
				observer.sendNext(2)
				samplerObserver.sendNext("a")
				expect(result) == [ "2a" ]
			}
			
			it("should do nothing if sampler fires before signal receives value") {
				var result: [String] = []
				sampledProducer.startWithNext { (left, right) in result.append("\(left)\(right)") }
				
				samplerObserver.sendNext("a")
				expect(result).to(beEmpty())
			}
			
			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [String] = []
				sampledProducer.startWithNext { (left, right) in result.append("\(left)\(right)") }
				
				observer.sendNext(1)
				samplerObserver.sendNext("a")
				samplerObserver.sendNext("b")
				expect(result) == [ "1a", "1b" ]
			}
			
			it("should complete when both inputs have completed") {
				var completed = false
				sampledProducer.startWithCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed) == false
				
				samplerObserver.sendCompleted()
				expect(completed) == true
			}
			
			it("should emit an initial value if the sampler is a synchronous SignalProducer") {
				let producer = SignalProducer<Int, NoError>(values: [1])
				let sampler = SignalProducer<String, NoError>(value: "a")
				
				let result = producer.sampleWith(sampler)
				
				var valueReceived: String?
				result.startWithNext { (left, right) in valueReceived = "\(left)\(right)" }
				
				expect(valueReceived) == "1a"
			}
		}

		describe("sampleOn") {
			var sampledProducer: SignalProducer<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<(), NoError>.Observer!
			
			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, NoError>.pipe()
				let (sampler, incomingSamplerObserver) = SignalProducer<(), NoError>.pipe()
				sampledProducer = producer.sampleOn(sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}
			
			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledProducer.startWithNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				samplerObserver.sendNext(())
				expect(result) == [ 2 ]
			}
			
			it("should do nothing if sampler fires before signal receives value") {
				var result: [Int] = []
				sampledProducer.startWithNext { result.append($0) }
				
				samplerObserver.sendNext(())
				expect(result).to(beEmpty())
			}
			
			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [Int] = []
				sampledProducer.startWithNext { result.append($0) }
				
				observer.sendNext(1)
				samplerObserver.sendNext(())
				samplerObserver.sendNext(())
				expect(result) == [ 1, 1 ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledProducer.startWithCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed) == false
				
				samplerObserver.sendCompleted()
				expect(completed) == true
			}

			it("should emit an initial value if the sampler is a synchronous SignalProducer") {
				let producer = SignalProducer<Int, NoError>(values: [1])
				let sampler = SignalProducer<(), NoError>(value: ())
				
				let result = producer.sampleOn(sampler)
				
				var valueReceived: Int?
				result.startWithNext { valueReceived = $0 }
				
				expect(valueReceived) == 1
			}

			describe("memory") {
				class Payload {
					let action: () -> Void

					init(onDeinit action: () -> Void) {
						self.action = action
					}

					deinit {
						action()
					}
				}

				var sampledProducer: SignalProducer<Payload, NoError>!
				var observer: Signal<Payload, NoError>.Observer!

				beforeEach {
					let (producer, incomingObserver) = SignalProducer<Payload, NoError>.pipe()
					let (sampler, _) = Signal<(), NoError>.pipe()
					sampledProducer = producer.sampleOn(sampler)
					observer = incomingObserver
				}

				it("should free payload when interrupted after complete of incoming producer") {
					var payloadFreed = false

					let disposable = sampledProducer.start()

					observer.sendNext(Payload { payloadFreed = true })
					observer.sendCompleted()

					expect(payloadFreed) == false

					disposable.dispose()
					expect(payloadFreed) == true
				}
			}
		}

		describe("combineLatestWith") {
			var combinedProducer: SignalProducer<(Int, Double), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var otherObserver: Signal<Double, NoError>.Observer!
			
			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, NoError>.pipe()
				let (otherSignal, incomingOtherObserver) = SignalProducer<Double, NoError>.pipe()
				combinedProducer = producer.combineLatestWith(otherSignal)
				observer = incomingObserver
				otherObserver = incomingOtherObserver
			}
			
			it("should forward the latest values from both inputs") {
				var latest: (Int, Double)?
				combinedProducer.startWithNext { latest = $0 }
				
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
				combinedProducer.startWithCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed) == false
				
				otherObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("zipWith") {
			var leftObserver: Signal<Int, NoError>.Observer!
			var rightObserver: Signal<String, NoError>.Observer!
			var zipped: SignalProducer<(Int, String), NoError>!

			beforeEach {
				let (leftProducer, incomingLeftObserver) = SignalProducer<Int, NoError>.pipe()
				let (rightProducer, incomingRightObserver) = SignalProducer<String, NoError>.pipe()

				leftObserver = incomingLeftObserver
				rightObserver = incomingRightObserver
				zipped = leftProducer.zipWith(rightProducer)
			}

			it("should combine pairs") {
				var result: [String] = []
				zipped.startWithNext { (left, right) in result.append("\(left)\(right)") }

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

				zipped.start { event in
					switch event {
					case let .Next(left, right):
						result.append("\(left)\(right)")
					case .Completed:
						completed = true
					case .Failed, .Interrupted:
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
		}

		describe("materialize") {
			it("should reify events from the signal") {
				let (producer, observer) = SignalProducer<Int, TestError>.pipe()
				var latestEvent: Event<Int, TestError>?
				producer
					.materialize()
					.startWithNext { latestEvent = $0 }
				
				observer.sendNext(2)
				
				expect(latestEvent).toNot(beNil())
				if let latestEvent = latestEvent {
					switch latestEvent {
					case let .Next(value):
						expect(value) == 2
					case .Failed, .Completed, .Interrupted:
						fail()
					}
				}
				
				observer.sendFailed(TestError.Default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .Failed:
						break
					case .Next, .Completed, .Interrupted:
						fail()
					}
				}
			}
		}

		describe("dematerialize") {
			typealias IntEvent = Event<Int, TestError>
			var observer: Signal<IntEvent, NoError>.Observer!
			var dematerialized: SignalProducer<Int, TestError>!
			
			beforeEach {
				let (producer, incomingObserver) = SignalProducer<IntEvent, NoError>.pipe()
				observer = incomingObserver
				dematerialized = producer.dematerialize()
			}
			
			it("should send values for Next events") {
				var result: [Int] = []
				dematerialized
					.assumeNoErrors()
					.startWithNext { result.append($0) }
				
				expect(result).to(beEmpty())
				
				observer.sendNext(.Next(2))
				expect(result) == [ 2 ]
				
				observer.sendNext(.Next(4))
				expect(result) == [ 2, 4 ]
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.startWithFailed { _ in errored = true }
				
				expect(errored) == false
				
				observer.sendNext(.Failed(TestError.Default))
				expect(errored) == true
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.startWithCompleted { completed = true }
				
				expect(completed) == false
				observer.sendNext(IntEvent.Completed)
				expect(completed) == true
			}
		}

		describe("takeLast") {
			var observer: Signal<Int, TestError>.Observer!
			var lastThree: SignalProducer<Int, TestError>!
				
			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, TestError>.pipe()
				observer = incomingObserver
				lastThree = producer.takeLast(3)
			}
			
			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree
					.assumeNoErrors()
					.startWithNext { result.append($0) }
				
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
					.startWithNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendCompleted()
				expect(result) == [ 1, 2 ]
			}
			
			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.start { event in
					switch event {
					case let .Next(value):
						result.append(value)
					case .Failed:
						errored = true
					case .Completed, .Interrupted:
						break
					}
				}
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)
				expect(errored) == false
				
				observer.sendFailed(TestError.Default)
				expect(errored) == true
				expect(result).to(beEmpty())
			}
		}

		describe("timeoutWithError") {
			var testScheduler: TestScheduler!
			var producer: SignalProducer<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			beforeEach {
				testScheduler = TestScheduler()
				let (baseProducer, incomingObserver) = SignalProducer<Int, TestError>.pipe()
				producer = baseProducer.timeoutWithError(TestError.Default, afterInterval: 2, onScheduler: testScheduler)
				observer = incomingObserver
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				producer.start { event in
					switch event {
					case .Completed:
						completed = true
					case .Failed:
						errored = true
					case .Next, .Interrupted:
						break
					}
				}

				testScheduler.scheduleAfter(1) {
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
				producer.start { event in
					switch event {
					case .Completed:
						completed = true
					case .Failed:
						errored = true
					case .Next, .Interrupted:
						break
					}
				}

				testScheduler.scheduleAfter(3) {
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
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attempt { _ in
					return .Success()
				}
				
				var current: Int?
				producer
					.assumeNoErrors()
					.startWithNext { value in
						current = value
					}
				
				for value in 1...5 {
					observer.sendNext(value)
					expect(current) == value
				}
			}
			
			it("should error if an attempt fails") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attempt { _ in
					return .Failure(.Default)
				}
				
				var error: TestError?
				producer.startWithFailed { err in
					error = err
				}
				
				observer.sendNext(42)
				expect(error) == TestError.Default
			}
		}
		
		describe("attemptMap") {
			it("should forward mapped values upon success") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attemptMap { num -> Result<Bool, TestError> in
					return .Success(num % 2 == 0)
				}
				
				var even: Bool?
				producer
					.assumeNoErrors()
					.startWithNext { value in
						even = value
					}
				
				observer.sendNext(1)
				expect(even) == false
				
				observer.sendNext(2)
				expect(even) == true
			}
			
			it("should error if a mapping fails") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attemptMap { _ -> Result<Bool, TestError> in
					return .Failure(.Default)
				}
				
				var error: TestError?
				producer.startWithFailed { err in
					error = err
				}
				
				observer.sendNext(42)
				expect(error) == TestError.Default
			}
		}
		
		describe("combinePrevious") {
			var observer: Signal<Int, NoError>.Observer!
			let initialValue: Int = 0
			var latestValues: (Int, Int)?
			
			beforeEach {
				latestValues = nil
				
				let (signal, baseObserver) = SignalProducer<Int, NoError>.pipe()
				observer = baseObserver
				signal.combinePrevious(initialValue).startWithNext { latestValues = $0 }
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
	}
}
