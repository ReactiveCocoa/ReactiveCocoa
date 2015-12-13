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
				Signal<AnyObject, NoError> { observer in
					didRunGenerator = true
					return nil
				}
				
				expect(didRunGenerator).to(beTruthy())
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
					return nil
				}
				
				var fromSignal: [Int] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .Next(number):
						fromSignal.append(number)
					case .Completed:
						completed = true
					default:
						break
					}
				}
				
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
						observer.sendFailed(TestError.Default)
					}
					return disposable
				}
				
				var errored = false
				
				signal.observeFailed { _ in errored = true }
				
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
						observer.sendCompleted()
					}
					return disposable
				}
				
				var completed = false
				
				signal.observeCompleted { completed = true }
				
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
						observer.sendInterrupted()
					}
					return disposable
				}

				var interrupted = false
				signal.observeInterrupted {
					interrupted = true
				}

				expect(interrupted).to(beFalsy())
				expect(disposable.disposed).to(beFalsy())

				testScheduler.run()

				expect(interrupted).to(beTruthy())
				expect(disposable.disposed).to(beTruthy())
			}
		}

		describe("Signal.pipe") {
			it("should forward events to observers") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				
				var fromSignal: [Int] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .Next(number):
						fromSignal.append(number)
					case .Completed:
						completed = true
					default:
						break
					}
				}
				
				expect(fromSignal).to(beEmpty())
				expect(completed).to(beFalsy())
				
				observer.sendNext(1)
				expect(fromSignal).to(equal([ 1 ]))
				
				observer.sendNext(2)
				expect(fromSignal).to(equal([ 1, 2 ]))
				
				expect(completed).to(beFalsy())
				observer.sendCompleted()
				expect(completed).to(beTruthy())
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
					testScheduler.schedule {
						for number in [ 1, 2 ] {
							observer.sendNext(number)
						}
						observer.sendCompleted()
						observer.sendNext(4)
					}
					return disposable
				}
				
				var fromSignal: [Int] = []
				signal.observeNext { number in
					fromSignal.append(number)
				}
				
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
				
				signal.observe(Observer<(), NoError>())
				expect(runCount).to(equal(1))
			}

			it("should release observer after termination") {
				weak var testStr: NSMutableString?
				let (signal, observer) = Signal<Int, NoError>.pipe()

				let test: () -> () = {
					let innerStr: NSMutableString = NSMutableString()
					signal.observeNext { value in
						innerStr.appendString("\(value)")
					}
					testStr = innerStr
				}
				test()

				observer.sendNext(1)
				expect(testStr).to(equal("1"))
				observer.sendNext(2)
				expect(testStr).to(equal("12"))

				observer.sendCompleted()
				expect(testStr).to(beNil())
			}

			it("should release observer after interruption") {
				weak var testStr: NSMutableString?
				let (signal, observer) = Signal<Int, NoError>.pipe()

				let test: () -> () = {
					let innerStr: NSMutableString = NSMutableString()
					signal.observeNext { value in
						innerStr.appendString("\(value)")
					}

					testStr = innerStr
				}

				test()

				observer.sendNext(1)
				expect(testStr).to(equal("1"))

				observer.sendNext(2)
				expect(testStr).to(equal("12"))

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
				expect(values).to(equal([1]))
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
				expect(lastValue).to(equal("1"))

				observer.sendNext(1)
				expect(lastValue).to(equal("2"))
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

				observer.sendFailed(TestError.Default)
				expect(error).to(equal(producerError))
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
				expect(lastValue).to(equal(0))

				observer.sendNext(1)
				expect(lastValue).to(equal(0))

				observer.sendNext(2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("Signal.merge") {
			it("should emit values from all signals") {
				let (signal1, observer1) = Signal<Int, NoError>.pipe()
				let (signal2, observer2) = Signal<Int, NoError>.pipe()

				let mergedSignals = Signal.merge([signal1, signal2])

				var lastValue: Int?
				mergedSignals.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer1.sendNext(1)
				expect(lastValue) == 1

				observer2.sendNext(2)
				expect(lastValue) == 2

				observer1.sendNext(3)
				expect(lastValue) == 3
			}

			it("should not stop when one signal completes") {
				let (signal1, observer1) = Signal<Int, NoError>.pipe()
				let (signal2, observer2) = Signal<Int, NoError>.pipe()

				let mergedSignals = Signal.merge([signal1, signal2])

				var lastValue: Int?
				mergedSignals.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer1.sendNext(1)
				expect(lastValue) == 1

				observer1.sendCompleted()
				expect(lastValue) == 1

				observer2.sendNext(2)
				expect(lastValue) == 2
			}

			it("should complete when all signals complete") {
				let (signal1, observer1) = Signal<Int, NoError>.pipe()
				let (signal2, observer2) = Signal<Int, NoError>.pipe()

				let mergedSignals = Signal.merge([signal1, signal2])

				var completed = false
				mergedSignals.observeCompleted { completed = true }

				expect(completed) == false

				observer1.sendNext(1)
				expect(completed) == false

				observer1.sendCompleted()
				expect(completed) == false

				observer2.sendCompleted()
				expect(completed) == true
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
				expect(lastValue).to(equal(1))

				observer.sendNext(nil)
				expect(lastValue).to(equal(1))

				observer.sendNext(2)
				expect(lastValue).to(equal(2))
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
				expect(lastValue).to(equal("a"))

				observer.sendNext("bb")
				expect(lastValue).to(equal("abb"))
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
					case let .Next(value):
						lastValue = value
					case .Completed:
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

				expect(completed).to(beFalse())
				observer.sendCompleted()
				expect(completed).to(beTrue())

				expect(lastValue).to(equal(4))
			}

			it("should send the initial value if none are received") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				observer.sendCompleted()

				expect(lastValue).to(equal(1))
				expect(completed).to(beTrue())
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.skip(1)

				var lastValue: Int?
				signal.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue).to(equal(2))
			}

			it("should not skip any values when 0") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.skip(0)

				var lastValue: Int?
				signal.observeNext { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(equal(1))

				observer.sendNext(2)
				expect(lastValue).to(equal(2))
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseSignal, observer) = Signal<Bool, NoError>.pipe()
				let signal = baseSignal.skipRepeats()

				var values: [Bool] = []
				signal.observeNext { values.append($0) }

				expect(values).to(equal([]))

				observer.sendNext(true)
				expect(values).to(equal([ true ]))

				observer.sendNext(true)
				expect(values).to(equal([ true ]))

				observer.sendNext(false)
				expect(values).to(equal([ true, false ]))

				observer.sendNext(true)
				expect(values).to(equal([ true, false, true ]))
			}

			it("should skip values according to a predicate") {
				let (baseSignal, observer) = Signal<String, NoError>.pipe()
				let signal = baseSignal.skipRepeats { $0.characters.count == $1.characters.count }

				var values: [String] = []
				signal.observeNext { values.append($0) }

				expect(values).to(equal([]))

				observer.sendNext("a")
				expect(values).to(equal([ "a" ]))

				observer.sendNext("b")
				expect(values).to(equal([ "a" ]))

				observer.sendNext("cc")
				expect(values).to(equal([ "a", "cc" ]))

				observer.sendNext("d")
				expect(values).to(equal([ "a", "cc", "d" ]))
			}
		}

		describe("skipWhile") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()

				signal = baseSignal.skipWhile { $0 < 2 }
				observer = incomingObserver
				lastValue = nil

				signal.observeNext { lastValue = $0 }
			}

			it("should skip while the predicate is true") {
				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(beNil())

				observer.sendNext(2)
				expect(lastValue).to(equal(2))

				observer.sendNext(0)
				expect(lastValue).to(equal(0))
			}

			it("should not skip any values when the predicate starts false") {
				expect(lastValue).to(beNil())

				observer.sendNext(3)
				expect(lastValue).to(equal(3))

				observer.sendNext(1)
				expect(lastValue).to(equal(1))
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
				
				signal = baseSignal.skipUntil(triggerSignal)
				observer = incomingObserver
				triggerObserver = incomingTriggerObserver
				
				lastValue = nil
				
				signal.observe { event in
					switch event {
					case let .Next(value):
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
				expect(lastValue).to(equal(0))
			}
			
			it("should skip values until the trigger completes") {
				expect(lastValue).to(beNil())
				
				observer.sendNext(1)
				expect(lastValue).to(beNil())
				
				observer.sendNext(2)
				expect(lastValue).to(beNil())
				
				triggerObserver.sendCompleted()
				observer.sendNext(0)
				expect(lastValue).to(equal(0))
			}
		}

		describe("take") {
			it("should take initial values") {
				let (baseSignal, observer) = Signal<Int, NoError>.pipe()
				let signal = baseSignal.take(2)

				var lastValue: Int?
				var completed = false
				signal.observe { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				observer.sendNext(1)
				expect(lastValue).to(equal(1))
				expect(completed).to(beFalse())

				observer.sendNext(2)
				expect(lastValue).to(equal(2))
				expect(completed).to(beTrue())
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
					return nil
				}
				
				var completed = false
				
				signal = signal.take(numbers.count)
				signal.observeCompleted { completed = true }
				
				expect(completed).to(beFalsy())
				testScheduler.run()
				expect(completed).to(beTruthy())
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
					return nil
				}

				var result: [Int] = []
				var interrupted = false

				signal
				.take(0)
				.observe { event in
					switch event {
					case let .Next(number):
						result.append(number)
					case .Interrupted:
						interrupted = true
					default:
						break
					}
				}

				expect(interrupted).to(beTruthy())

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
				expect(result).to(equal(expectedResult))
			}

			it("should complete with an empty array if there are no values") {
				let (original, observer) = Signal<Int, NoError>.pipe()
				let signal = original.collect()

				var result: [Int]?

				signal.observeNext { result = $0 }

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result).to(equal([]))
			}

			it("should forward errors") {
				let (original, observer) = Signal<Int, TestError>.pipe()
				let signal = original.collect()

				var error: TestError?

				signal.observeFailed { error = $0 }

				expect(error).to(beNil())
				observer.sendFailed(.Default)
				expect(error).to(equal(TestError.Default))
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

				signal = baseSignal.takeUntil(triggerSignal)
				observer = incomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil
				completed = false

				signal.observe { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values until the trigger fires") {
				expect(lastValue).to(beNil())

				observer.sendNext(1)
				expect(lastValue).to(equal(1))

				observer.sendNext(2)
				expect(lastValue).to(equal(2))

				expect(completed).to(beFalse())
				triggerObserver.sendNext(())
				expect(completed).to(beTrue())
			}
			
			it("should take values until the trigger completes") {
				expect(lastValue).to(beNil())
				
				observer.sendNext(1)
				expect(lastValue).to(equal(1))
				
				observer.sendNext(2)
				expect(lastValue).to(equal(2))
				
				expect(completed).to(beFalse())
				triggerObserver.sendCompleted()
				expect(completed).to(beTrue())
			}

			it("should complete if the trigger fires immediately") {
				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				triggerObserver.sendNext(())

				expect(completed).to(beTrue())
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

				signal = baseSignal.takeUntilReplacement(replacementSignal)
				observer = incomingObserver
				replacementObserver = incomingReplacementObserver

				lastValue = nil
				completed = false

				signal.observe { event in
					switch event {
					case let .Next(value):
						lastValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values from the original then the replacement") {
				expect(lastValue).to(beNil())
				expect(completed).to(beFalse())

				observer.sendNext(1)
				expect(lastValue).to(equal(1))

				observer.sendNext(2)
				expect(lastValue).to(equal(2))

				replacementObserver.sendNext(3)

				expect(lastValue).to(equal(3))
				expect(completed).to(beFalse())

				observer.sendNext(4)

				expect(lastValue).to(equal(3))
				expect(completed).to(beFalse())

				replacementObserver.sendNext(5)
				expect(lastValue).to(equal(5))

				expect(completed).to(beFalse())
				replacementObserver.sendCompleted()
				expect(completed).to(beTrue())
			}
		}

		describe("takeWhile") {
			var signal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, NoError>.pipe()
				signal = baseSignal.takeWhile { $0 <= 4 }
				observer = incomingObserver
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				signal.observe { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				for value in -1...4 {
					observer.sendNext(value)
					expect(latestValue).to(equal(value))
					expect(completed).to(beFalse())
				}

				observer.sendNext(5)
				expect(latestValue).to(equal(4))
				expect(completed).to(beTrue())
			}

			it("should complete if the predicate starts false") {
				var latestValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(5)
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
					.observeOn(testScheduler)
					.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				expect(result).to(beEmpty())
				
				testScheduler.run()
				expect(result).to(equal([ 1, 2 ]))
			}
		}

		describe("delay") {
			it("should send events on the given scheduler after the interval") {
				let testScheduler = TestScheduler()
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						observer.sendNext(1)
					}
					testScheduler.scheduleAfter(5, action: {
						observer.sendNext(2)
						observer.sendCompleted()
					})
					return nil
				}
				
				var result: [Int] = []
				var completed = false
				
				signal
					.delay(10, onScheduler: testScheduler)
					.observe { event in
						switch event {
						case let .Next(number):
							result.append(number)
						case .Completed:
							completed = true
						default:
							break
						}
					}
				
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
				let signal: Signal<Int, TestError> = Signal { observer in
					testScheduler.schedule {
						observer.sendFailed(TestError.Default)
					}
					return nil
				}
				
				var errored = false
				
				signal
					.delay(10, onScheduler: testScheduler)
					.observeFailed { _ in errored = true }
				
				testScheduler.advance()
				expect(errored).to(beTruthy())
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

				signal = baseSignal.throttle(1, onScheduler: scheduler)
				expect(signal).notTo(beNil())
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				signal.observeNext { value in
					values.append(value)
				}

				expect(values).to(equal([]))

				observer.sendNext(0)
				expect(values).to(equal([]))

				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				observer.sendNext(1)
				observer.sendNext(2)
				expect(values).to(equal([ 0 ]))

				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ 0, 2 ]))

				scheduler.advanceByInterval(3)
				expect(values).to(equal([ 0, 2 ]))

				observer.sendNext(3)
				expect(values).to(equal([ 0, 2 ]))

				scheduler.advance()
				expect(values).to(equal([ 0, 2, 3 ]))

				observer.sendNext(4)
				observer.sendNext(5)
				scheduler.advance()
				expect(values).to(equal([ 0, 2, 3 ]))

				scheduler.run()
				expect(values).to(equal([ 0, 2, 3, 5 ]))
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case .Completed:
						completed = true
					default:
						break
					}
				}

				observer.sendNext(0)
				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				observer.sendNext(1)
				observer.sendCompleted()
				expect(completed).to(beFalsy())

				scheduler.run()
				expect(values).to(equal([ 0 ]))
				expect(completed).to(beTruthy())
			}
		}

		describe("sampleOn") {
			var sampledSignal: Signal<Int, NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var samplerObserver: Signal<(), NoError>.Observer!
			
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (sampler, incomingSamplerObserver) = Signal<(), NoError>.pipe()
				sampledSignal = signal.sampleOn(sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}
			
			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledSignal.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				samplerObserver.sendNext(())
				expect(result).to(equal([ 2 ]))
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
				expect(result).to(equal([ 1, 1 ]))
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledSignal.observeCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed).to(beFalsy())
				
				samplerObserver.sendCompleted()
				expect(completed).to(beTruthy())
			}
		}

		describe("combineLatestWith") {
			var combinedSignal: Signal<(Int, Double), NoError>!
			var observer: Signal<Int, NoError>.Observer!
			var otherObserver: Signal<Double, NoError>.Observer!
			
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, NoError>.pipe()
				let (otherSignal, incomingOtherObserver) = Signal<Double, NoError>.pipe()
				combinedSignal = signal.combineLatestWith(otherSignal)
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
				expect(latest?.0).to(equal(1))
				expect(latest?.1).to(equal(1.5))
				
				observer.sendNext(2)
				expect(latest?.0).to(equal(2))
				expect(latest?.1).to(equal(1.5))
			}

			it("should complete when both inputs have completed") {
				var completed = false
				combinedSignal.observeCompleted { completed = true }
				
				observer.sendCompleted()
				expect(completed).to(beFalsy())
				
				otherObserver.sendCompleted()
				expect(completed).to(beTruthy())
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
				zipped = leftSignal.zipWith(rightSignal)
			}

			it("should combine pairs") {
				var result: [String] = []
				zipped.observeNext { (left, right) in result.append("\(left)\(right)") }

				leftObserver.sendNext(1)
				leftObserver.sendNext(2)
				expect(result).to(equal([]))

				rightObserver.sendNext("foo")
				expect(result).to(equal([ "1foo" ]))

				leftObserver.sendNext(3)
				rightObserver.sendNext("bar")
				expect(result).to(equal([ "1foo", "2bar" ]))

				rightObserver.sendNext("buzz")
				expect(result).to(equal([ "1foo", "2bar", "3buzz" ]))

				rightObserver.sendNext("fuzz")
				expect(result).to(equal([ "1foo", "2bar", "3buzz" ]))

				leftObserver.sendNext(4)
				expect(result).to(equal([ "1foo", "2bar", "3buzz", "4fuzz" ]))
			}

			it("should complete when the shorter signal has completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .Next(left, right):
						result.append("\(left)\(right)")
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(completed).to(beFalsy())

				leftObserver.sendNext(0)
				leftObserver.sendCompleted()
				expect(completed).to(beFalsy())
				expect(result).to(equal([]))

				rightObserver.sendNext("foo")
				expect(completed).to(beTruthy())
				expect(result).to(equal([ "0foo" ]))
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
					case let .Next(value):
						expect(value).to(equal(2))
					default:
						fail()
					}
				}
				
				observer.sendFailed(TestError.Default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .Failed(_):
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
				dematerialized.observeNext { result.append($0) }
				
				expect(result).to(beEmpty())
				
				observer.sendNext(.Next(2))
				expect(result).to(equal([ 2 ]))
				
				observer.sendNext(.Next(4))
				expect(result).to(equal([ 2, 4 ]))
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.observeFailed { _ in errored = true }
				
				expect(errored).to(beFalsy())
				
				observer.sendNext(.Failed(TestError.Default))
				expect(errored).to(beTruthy())
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.observeCompleted { completed = true }
				
				expect(completed).to(beFalsy())
				observer.sendNext(IntEvent.Completed)
				expect(completed).to(beTruthy())
			}
		}

		describe("takeLast") {
			var observer: Signal<Int, TestError>.Observer!
			var lastThree: Signal<Int, TestError>!
				
			beforeEach {
				let (signal, incomingObserver) = Signal<Int, TestError>.pipe()
				observer = incomingObserver
				lastThree = signal.takeLast(3)
			}

			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)
				observer.sendNext(4)
				expect(result).to(beEmpty())
				
				observer.sendCompleted()
				expect(result).to(equal([ 2, 3, 4 ]))
			}

			it("should send less than N values if not enough were received") {
				var result: [Int] = []
				lastThree.observeNext { result.append($0) }
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendCompleted()
				expect(result).to(equal([ 1, 2 ]))
			}
			
			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.observe { event in
					switch event {
					case let .Next(value):
						result.append(value)
					case .Failed(_):
						errored = true
					default:
						break
					}
				}
				
				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)
				expect(errored).to(beFalsy())
				
				observer.sendFailed(TestError.Default)
				expect(errored).to(beTruthy())
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
				signal = baseSignal.timeoutWithError(TestError.Default, afterInterval: 2, onScheduler: testScheduler)
				observer = incomingObserver
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				signal.observe { event in
					switch event {
					case .Completed:
						completed = true
					case .Failed(_):
						errored = true
					default:
						break
					}
				}

				testScheduler.scheduleAfter(1) {
					observer.sendCompleted()
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
				signal.observe { event in
					switch event {
					case .Completed:
						completed = true
					case .Failed(_):
						errored = true
					default:
						break
					}
				}

				testScheduler.scheduleAfter(3) {
					observer.sendCompleted()
				}

				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				testScheduler.run()
				expect(completed).to(beFalsy())
				expect(errored).to(beTruthy())
			}
		}

		describe("attempt") {
			it("should forward original values upon success") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attempt { _ in
					return .Success()
				}
				
				var current: Int?
				signal.observeNext { value in
					current = value
				}
				
				for value in 1...5 {
					observer.sendNext(value)
					expect(current).to(equal(value))
				}
			}
			
			it("should error if an attempt fails") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attempt { _ in
					return .Failure(.Default)
				}
				
				var error: TestError?
				signal.observeFailed { err in
					error = err
				}
				
				observer.sendNext(42)
				expect(error).to(equal(TestError.Default))
			}
		}
		
		describe("attemptMap") {
			it("should forward mapped values upon success") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attemptMap { num -> Result<Bool, TestError> in
					return .Success(num % 2 == 0)
				}
				
				var even: Bool?
				signal.observeNext { value in
					even = value
				}
				
				observer.sendNext(1)
				expect(even).to(equal(false))
				
				observer.sendNext(2)
				expect(even).to(equal(true))
			}
			
			it("should error if a mapping fails") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attemptMap { _ -> Result<Bool, TestError> in
					return .Failure(.Default)
				}
				
				var error: TestError?
				signal.observeFailed { err in
					error = err
				}
				
				observer.sendNext(42)
				expect(error).to(equal(TestError.Default))
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
				expect(latestValues?.0).to(equal(initialValue))
				expect(latestValues?.1).to(equal(1))
				
				observer.sendNext(2)
				expect(latestValues?.0).to(equal(1))
				expect(latestValues?.1).to(equal(2))
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
					expect(combinedValues).to(equal([0, 1, 2]))
					
					observerA.sendNext(10)
					expect(combinedValues).to(equal([10, 1, 2]))
				}
				
				it("should not forward the latest values before all inputs"){
					expect(combinedValues).to(beNil())
					
					observerA.sendNext(0)
					expect(combinedValues).to(beNil())
					
					observerB.sendNext(1)
					expect(combinedValues).to(beNil())
					
					observerC.sendNext(2)
					expect(combinedValues).to(equal([0, 1, 2]))
				}
				
				it("should complete when all inputs have completed"){
					expect(completed).to(beFalsy())
					
					observerA.sendCompleted()
					observerB.sendCompleted()
					expect(completed).to(beFalsy())
					
					observerC.sendCompleted()
					expect(completed).to(beTruthy())
				}
			}
			
			describe("tuple") {
				beforeEach {
					combineLatest(signalA, signalB, signalC)
						.observe { event in
							switch event {
							case let .Next(value):
								combinedValues = [value.0, value.1, value.2]
							case .Completed:
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
					combineLatest([signalA, signalB, signalC])
					.observe { event in
						switch event {
						case let .Next(values):
							combinedValues = values
						case .Completed:
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
					expect(zippedValues).to(equal([0, 1, 2]))
					
					observerA.sendNext(10)
					expect(zippedValues).to(equal([0, 1, 2]))
					
					observerA.sendNext(20)
					expect(zippedValues).to(equal([0, 1, 2]))
					
					observerB.sendNext(11)
					expect(zippedValues).to(equal([0, 1, 2]))
					
					observerC.sendNext(12)
					expect(zippedValues).to(equal([10, 11, 12]))
				}
				
				it("should complete when the shorter signal has completed"){
					expect(completed).to(beFalsy())
					
					observerB.sendNext(1)
					observerC.sendNext(2)
					observerB.sendCompleted()
					observerC.sendCompleted()
					expect(completed).to(beFalsy())
					
					observerA.sendNext(0)
					expect(completed).to(beTruthy())
				}
			}
			
			describe("tuple") {
				beforeEach {
					zip(signalA, signalB, signalC)
						.observe { event in
							switch event {
							case let .Next(value):
								zippedValues = [value.0, value.1, value.2]
							case .Completed:
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
					zip([signalA, signalB, signalC])
						.observe { event in
							switch event {
							case let .Next(values):
								zippedValues = values
							case .Completed:
								completed = true
							default:
								break
							}
						}
				}
				
				itBehavesLike(zipExampleName)
			}
		}
	}
}
