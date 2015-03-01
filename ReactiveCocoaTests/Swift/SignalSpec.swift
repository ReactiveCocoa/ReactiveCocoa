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
			it("should omit values from the signal") {
				let numbers = [ 1, 2, 4, 5 ]
				var testScheduler = TestScheduler()
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
					}
					return nil
				}
				
				var afterFilter: [Int] = []
				
				signal
				|> filter { $0 % 2 == 0 }
				|> observe(next: { afterFilter.append($0) })
				
				testScheduler.run()
				expect(afterFilter).to(equal([2, 4]))
			}
		}

		describe("scan") {
			it("should incrementally accumulate a value") {
				let numbers = [ 1, 2, 4, 5 ]
				var testScheduler = TestScheduler()
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
					}
					return nil
				}
				
				var scanned: [Int] = []
				
				signal
				|> scan(0) { $0 + $1 }
				|> observe(next: { scanned.append($0) })
				
				testScheduler.run()
				expect(scanned).to(equal([1, 3, 7, 12]))
			}
		}

		describe("reduce") {
			it("should accumulate one value") {
				let numbers = [ 1, 2, 4, 5 ]
				var testScheduler = TestScheduler()
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						for number in numbers {
							sendNext(observer, number)
						}
						sendCompleted(observer)
					}
					return nil
				}
				
				var result: [Int] = []
				
				signal
				|> reduce(0) { $0 + $1 }
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				
				// using array to make sure only one value sent
				expect(result).to(equal([12]))
			}

			it("should send the initial value if none are received") {
				var testScheduler = TestScheduler()
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						sendCompleted(observer)
					}
					return nil
				}
				
				var result: [Int] = []
				
				signal
				|> reduce(99) { $0 + $1 }
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([99]))
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let numbers = [ 1, 2, 4, 5 ]
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
				
				signal
				|> skip(2)
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([4, 5]))
			}

			it("should not skip any values when 0") {
				let numbers = [ 1, 2, 4, 5 ]
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
				
				signal
				|> skip(0)
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal(numbers))
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
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
				
				signal
				|> skipRepeats
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([1, 2, 4, 5]))
			}

			it("should skip values according to a predicate") {
				let letters = [ "A", "a", "b", "c", "C", "V" ]
				var testScheduler = TestScheduler()
				
				let signal: Signal<String, NoError> = Signal { observer in
					testScheduler.schedule {
						for letter in letters {
							sendNext(observer, letter)
						}
					}
					return nil
				}
				
				var result: [String] = []
				
				signal
				|> skipRepeats { $0.lowercaseString == $1.lowercaseString }
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([ "A", "b", "c", "V" ]))
			}
		}

		describe("skipWhile") {
			it("should skip while the predicate is true") {
				let numbers = [ 1, 2, 4, 4, 5, 2 ]
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
				
				signal
				|> skipWhile { $0 < 4 }
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([ 4, 4, 5, 2 ]))
			}

			it("should not skip any values when the predicate starts false") {
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
				
				signal
				|> skipWhile { _ in return false }
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([ 1, 2, 4, 4, 5 ]))
			}
		}

		describe("take") {
			it("should take initial values") {
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
				
				signal
				|> take(3)
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([ 1, 2, 4 ]))
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

				signal.observe(next: { value in
					result = value
					return
				})

				expect(result).to(beNil())
				sendCompleted(sink)
				expect(result).to(equal([]))
			}

			it("should forward errors") {
				let (original, sink) = Signal<Int, TestError>.pipe()
				let signal = original |> collect

				var error: TestError?

				signal.observe(error: { value in
					error = value
					return
				})

				expect(error).to(beNil())
				sendError(sink, .Default)
				expect(error).to(equal(TestError.Default))
			}
		}

		describe("takeUntil") {
			it("should take values until the trigger fires") {
				var testScheduler = TestScheduler()
				let triggerSignal: Signal<(), NoError> = Signal { observer in
					testScheduler.scheduleAfter(2, action: {
						sendCompleted(observer)
					})
					return nil
				}
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.scheduleAfter(1, action: {
						sendNext(observer, 3)
					})
					testScheduler.scheduleAfter(3, action: {
						sendNext(observer, 5)
					})
					return nil
				}
				
				var result: [Int] = []
				var completed = false
				
				signal
				|> takeUntil(triggerSignal)
				|> observe(next: { number in
					result.append(number)
				}, completed: {
					completed = true
				})
				
				expect(completed).to(beFalsy())
				
				testScheduler.run()
				expect(result).to(equal([3]))
				expect(completed).to(beTruthy())
			}

			it("should complete if the trigger fires immediately") {
				var testScheduler = TestScheduler()
				let triggerSignal: Signal<(), NoError> = Signal { observer in
					testScheduler.schedule {
						sendCompleted(observer)
					}
					return nil
				}
				
				let signal: Signal<Int, NoError> = Signal { observer in
					testScheduler.scheduleAfter(2, action: {
						sendNext(observer, 3)
					})
					testScheduler.scheduleAfter(3, action: {
						sendNext(observer, 5)
					})
					return nil
				}
				
				var result: [Int] = []
				var completed = false
				
				signal
				|> takeUntil(triggerSignal)
				|> observe(next: { number in
					result.append(number)
				}, completed: {
					completed = true
				})
				
				expect(completed).to(beFalsy())
				
				testScheduler.run()
				expect(result).to(beEmpty())
				expect(completed).to(beTruthy())
			}
		}

		describe("takeUntilReplacement") {
			it("should take values from the original then the replacement") {
				let testScheduler = TestScheduler()
				let originalSignal: Signal<Int, NoError> = Signal { observer in
					testScheduler.schedule {
						sendNext(observer, 1)
					}
					testScheduler.scheduleAfter(5, action: {
						sendNext(observer, 2)
					})
					return nil
				}
				let replacementSignal: Signal<Int, NoError> = Signal { observer in
					testScheduler.scheduleAfter(2, action: {
						sendNext(observer, 3)
					})
					testScheduler.scheduleAfter(6, action: {
						sendNext(observer, 4)
					})
					return nil
				}
				
				var result: [Int] = []
				originalSignal
				|> takeUntilReplacement(replacementSignal)
				|> observe(next: { result.append($0) })
				
				testScheduler.run()
				expect(result).to(equal([ 1, 3, 4 ]))
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
			var scheduler: TestScheduler!
			var observer: Signal<Int, NoError>.Observer!
			var signal: Signal<Int, NoError>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, NoError>.pipe()
				observer = baseObserver

				signal = baseSignal |> throttle(1, onScheduler: scheduler)
				expect(signal).notTo(beNil())
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				signal.observe(next: { value in
					values.append(value)
				})

				expect(values).to(equal([]))

				sendNext(observer, 0)
				expect(values).to(equal([]))

				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				sendNext(observer, 1)
				sendNext(observer, 2)
				expect(values).to(equal([ 0 ]))

				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ 0, 2 ]))

				scheduler.advanceByInterval(1)
				expect(values).to(equal([ 0, 2 ]))

				sendNext(observer, 3)
				expect(values).to(equal([ 0, 2 ]))

				scheduler.advance()
				expect(values).to(equal([ 0, 2, 3 ]))

				sendNext(observer, 4)
				sendNext(observer, 5)
				scheduler.advance()
				expect(values).to(equal([ 0, 2, 3 ]))

				scheduler.run()
				expect(values).to(equal([ 0, 2, 3, 5 ]))
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				signal.observe(next: { value in
					values.append(value)
				}, completed: {
					completed = true
				})

				sendNext(observer, 0)
				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				sendNext(observer, 1)
				sendCompleted(observer)
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
