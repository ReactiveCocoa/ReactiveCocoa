//
//  SignalProducerSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

import Result
import Nimble
import Quick
import ReactiveCocoa

class SignalProducerSpec: QuickSpec {
	override func spec() {
		describe("init") {
			it("should run the handler once per start()") {
				var handlerCalledTimes = 0
				let signalProducer = SignalProducer<String, NSError>() { observer, disposable in
					handlerCalledTimes += 1

					return
				}

				signalProducer.start()
				signalProducer.start()

				expect(handlerCalledTimes) == 2
			}

			it("should release signal observers when given disposable is disposed") {
				var disposable: Disposable!

				let producer = SignalProducer<Int, NoError> { observer, innerDisposable in
					disposable = innerDisposable

					innerDisposable.addDisposable {
						// This is necessary to keep the observer long enough to
						// even test the memory management.
						observer.sendNext(0)
					}
				}

				weak var objectRetainedByObserver: NSObject?
				producer.startWithSignal { signal, _ in
					let object = NSObject()
					objectRetainedByObserver = object
					signal.observeNext { _ in object }
				}

				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			it("should dispose of added disposables upon completion") {
				let addedDisposable = SimpleDisposable()
				var observer: Signal<(), NoError>.Observer!

				let producer = SignalProducer<(), NoError>() { incomingObserver, disposable in
					disposable.addDisposable(addedDisposable)
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.disposed) == false

				observer.sendCompleted()
				expect(addedDisposable.disposed) == true
			}

			it("should dispose of added disposables upon error") {
				let addedDisposable = SimpleDisposable()
				var observer: Signal<(), TestError>.Observer!

				let producer = SignalProducer<(), TestError>() { incomingObserver, disposable in
					disposable.addDisposable(addedDisposable)
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.disposed) == false

				observer.sendFailed(.Default)
				expect(addedDisposable.disposed) == true
			}

			it("should dispose of added disposables upon interruption") {
				let addedDisposable = SimpleDisposable()
				var observer: Signal<(), NoError>.Observer!

				let producer = SignalProducer<(), NoError>() { incomingObserver, disposable in
					disposable.addDisposable(addedDisposable)
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.disposed) == false

				observer.sendInterrupted()
				expect(addedDisposable.disposed) == true
			}

			it("should dispose of added disposables upon start() disposal") {
				let addedDisposable = SimpleDisposable()

				let producer = SignalProducer<(), TestError>() { _, disposable in
					disposable.addDisposable(addedDisposable)
					return
				}

				let startDisposable = producer.start()
				expect(addedDisposable.disposed) == false

				startDisposable.dispose()
				expect(addedDisposable.disposed) == true
			}
		}

		describe("init(signal:)") {
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			beforeEach {
				// Cannot directly assign due to compiler crash on Xcode 7.0.1
				let (signalTemp, observerTemp) = Signal<Int, TestError>.pipe()
				signal = signalTemp
				observer = observerTemp
			}

			it("should emit values then complete") {
				let producer = SignalProducer<Int, TestError>(signal: signal)

				var values: [Int] = []
				var error: TestError?
				var completed = false
				producer.start { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case let .Failed(err):
						error = err
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(values) == []
				expect(error).to(beNil())
				expect(completed) == false

				observer.sendNext(1)
				expect(values) == [ 1 ]
				observer.sendNext(2)
				observer.sendNext(3)
				expect(values) == [ 1, 2, 3 ]

				observer.sendCompleted()
				expect(completed) == true
			}

			it("should emit error") {
				let producer = SignalProducer<Int, TestError>(signal: signal)

				var error: TestError?
				let sentError = TestError.Default

				producer.start { event in
					switch event {
					case let .Failed(err):
						error = err
					default:
						break
					}
				}

				expect(error).to(beNil())

				observer.sendFailed(sentError)
				expect(error) == sentError
			}
		}

		describe("init(value:)") {
			it("should immediately send the value then complete") {
				let producerValue = "StringValue"
				let signalProducer = SignalProducer<String, NSError>(value: producerValue)

				expect(signalProducer).to(sendValue(producerValue, sendError: nil, complete: true))
			}
		}

		describe("init(error:)") {
			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let signalProducer = SignalProducer<Int, NSError>(error: producerError)

				expect(signalProducer).to(sendValue(nil, sendError: producerError, complete: false))
			}
		}

		describe("init(result:)") {
			it("should immediately send the value then complete") {
				let producerValue = "StringValue"
				let producerResult = .Success(producerValue) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				expect(signalProducer).to(sendValue(producerValue, sendError: nil, complete: true))
			}

			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let producerResult = .Failure(producerError) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				expect(signalProducer).to(sendValue(nil, sendError: producerError, complete: false))
			}
		}

		describe("init(values:)") {
			it("should immediately send the sequence of values") {
				let sequenceValues = [1, 2, 3]
				let signalProducer = SignalProducer<Int, NSError>(values: sequenceValues)

				expect(signalProducer).to(sendValues(sequenceValues, sendError: nil, complete: true))
			}
		}

		describe("SignalProducer.empty") {
			it("should immediately complete") {
				let signalProducer = SignalProducer<Int, NSError>.empty

				expect(signalProducer).to(sendValue(nil, sendError: nil, complete: true))
			}
		}

		describe("SignalProducer.never") {
			it("should not send any events") {
				let signalProducer = SignalProducer<Int, NSError>.never

				expect(signalProducer).to(sendValue(nil, sendError: nil, complete: false))
			}
		}

		describe("SignalProducer.buffer") {
			it("should replay buffered events when started, then forward events as added") {
				let (producer, observer) = SignalProducer<Int, NSError>.buffer(Int.max)

				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)

				var values: [Int] = []
				var completed = false
				producer.start { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(values) == [1, 2, 3]
				expect(completed) == false

				observer.sendNext(4)
				observer.sendNext(5)

				expect(values) == [1, 2, 3, 4, 5]
				expect(completed) == false

				observer.sendCompleted()

				expect(values) == [1, 2, 3, 4, 5]
				expect(completed) == true
			}

			it("should drop earliest events to maintain the capacity") {
				let (producer, observer) = SignalProducer<Int, TestError>.buffer(1)

				observer.sendNext(1)
				observer.sendNext(2)

				var values: [Int] = []
				var error: TestError?
				producer.start { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case let .Failed(err):
						error = err
					default:
						break
					}
				}
				
				expect(values) == [2]
				expect(error).to(beNil())

				observer.sendNext(3)
				observer.sendNext(4)

				expect(values) == [2, 3, 4]
				expect(error).to(beNil())

				observer.sendFailed(.Default)

				expect(values) == [2, 3, 4]
				expect(error) == TestError.Default
			}
			
			it("should always replay termination event") {
				let (producer, observer) = SignalProducer<Int, TestError>.buffer(0)
				var completed = false
				
				observer.sendCompleted()
				
				producer.startWithCompleted {
					completed = true
				}
				
				expect(completed) == true
			}
			
			it("should replay values after being terminated") {
				let (producer, observer) = SignalProducer<Int, TestError>.buffer(1)
				var value: Int?
				var completed = false
				
				observer.sendNext(123)
				observer.sendCompleted()
				
				producer.start { event in
					switch event {
					case let .Next(val):
						value = val
					case .Completed:
						completed = true
					default:
						break
					}
				}
				
				expect(value) == 123
				expect(completed) == true
			}

			it("should not deadlock when started while sending") {
				let (producer, observer) = SignalProducer<Int, NoError>.buffer(Int.max)

				observer.sendNext(1)
				observer.sendNext(2)
				observer.sendNext(3)

				var values: [Int] = []
				producer.startWithCompleted {
					values = []

					producer.startWithNext { value in
						values.append(value)
					}
				}

				observer.sendCompleted()
				expect(values) == [ 1, 2, 3 ]
			}

			it("should not deadlock in pair when started while sending") {
				let (producer1, observer1) = SignalProducer<String, NoError>.buffer(Int.max)
				let (producer2, observer2) = SignalProducer<String, NoError>.buffer(Int.max)

				observer1.sendNext("A")
				observer1.sendNext("B")
				observer2.sendNext("1")
				observer2.sendNext("2")

				var valuePairs: [String] = []
				producer1.startWithCompleted {
					producer2.startWithCompleted {
						valuePairs = []
						producer1.startWithNext { value1 in
							producer2.startWithNext { value2 in
								valuePairs.append(value1 + value2)
							}
						}
					}
				}

				observer1.sendCompleted()
				observer2.sendCompleted()
				expect(valuePairs) == [ "A1", "A2", "B1", "B2" ]
			}

			it("should buffer values before sending recursively to new observers") {
				let (producer, observer) = SignalProducer<Int, NoError>.buffer(Int.max)

				var values: [Int] = []
				var lastBufferedValues: [Int] = []

				producer.startWithNext { newValue in
					values.append(newValue)

					var bufferedValues: [Int] = []
					
					producer.startWithNext { bufferedValue in
						bufferedValues.append(bufferedValue)
					}

					expect(bufferedValues) == values
					lastBufferedValues = bufferedValues
				}

				observer.sendNext(1)
				expect(values) == [ 1 ]
				expect(lastBufferedValues) == values

				observer.sendNext(2)
				expect(values) == [ 1, 2 ]
				expect(lastBufferedValues) == values

				observer.sendNext(3)
				expect(values) == [ 1, 2, 3 ]
				expect(lastBufferedValues) == values
			}
		}

		describe("trailing closure") {
			it("receives next values") {
				let (producer, observer) = SignalProducer<Int, NoError>.pipe()

				var values = [Int]()
				producer.startWithNext { next in
					values.append(next)
				}

				observer.sendNext(1)
				expect(values) == [1]
			}
		}

		describe("SignalProducer.attempt") {
			it("should run the operation once per start()") {
				var operationRunTimes = 0
				let operation: () -> Result<String, NSError> = {
					operationRunTimes += 1

					return .Success("OperationValue")
				}

				SignalProducer.attempt(operation).start()
				SignalProducer.attempt(operation).start()

				expect(operationRunTimes) == 2
			}

			it("should send the value then complete") {
				let operationReturnValue = "OperationValue"
				let operation: () -> Result<String, NSError> = {
					return .Success(operationReturnValue)
				}

				let signalProducer = SignalProducer.attempt(operation)

				expect(signalProducer).to(sendValue(operationReturnValue, sendError: nil, complete: true))
			}

			it("should send the error") {
				let operationError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let operation: () -> Result<String, NSError> = {
					return .Failure(operationError)
				}

				let signalProducer = SignalProducer.attempt(operation)

				expect(signalProducer).to(sendValue(nil, sendError: operationError, complete: false))
			}
		}

		describe("startWithSignal") {
			it("should invoke the closure before any effects or events") {
				var started = false
				var value: Int?

				SignalProducer<Int, NoError>(value: 42)
					.on(started: {
						started = true
					}, next: {
						value = $0
					})
					.startWithSignal { _ in
						expect(started) == false
						expect(value).to(beNil())
					}

				expect(started) == true
				expect(value) == 42
			}

			it("should dispose of added disposables if disposed") {
				let addedDisposable = SimpleDisposable()
				var disposable: Disposable!

				let producer = SignalProducer<Int, NoError>() { _, disposable in
					disposable.addDisposable(addedDisposable)
					return
				}

				producer.startWithSignal { _, innerDisposable in
					disposable = innerDisposable
				}

				expect(addedDisposable.disposed) == false

				disposable.dispose()
				expect(addedDisposable.disposed) == true
			}

			it("should send interrupted if disposed") {
				var interrupted = false
				var disposable: Disposable!

				SignalProducer<Int, NoError>(value: 42)
					.startOn(TestScheduler())
					.startWithSignal { signal, innerDisposable in
						signal.observeInterrupted {
							interrupted = true
						}

						disposable = innerDisposable
					}

				expect(interrupted) == false

				disposable.dispose()
				expect(interrupted) == true
			}

			it("should release signal observers if disposed") {
				weak var objectRetainedByObserver: NSObject?
				var disposable: Disposable!

				let producer = SignalProducer<Int, NoError>.never
				producer.startWithSignal { signal, innerDisposable in
					let object = NSObject()
					objectRetainedByObserver = object
					signal.observeNext { _ in object.description }
					disposable = innerDisposable
				}

				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			it("should not trigger effects if disposed before closure return") {
				var started = false
				var value: Int?

				SignalProducer<Int, NoError>(value: 42)
					.on(started: {
						started = true
					}, next: {
						value = $0
					})
					.startWithSignal { _, disposable in
						expect(started) == false
						expect(value).to(beNil())

						disposable.dispose()
					}

				expect(started) == false
				expect(value).to(beNil())
			}

			it("should send interrupted if disposed before closure return") {
				var interrupted = false

				SignalProducer<Int, NoError>(value: 42)
					.startWithSignal { signal, disposable in
						expect(interrupted) == false

						signal.observeInterrupted {
							interrupted = true
						}

						disposable.dispose()
					}

				expect(interrupted) == true
			}

			it("should dispose of added disposables upon completion") {
				let addedDisposable = SimpleDisposable()
				var observer: Signal<Int, TestError>.Observer!

				let producer = SignalProducer<Int, TestError>() { incomingObserver, disposable in
					disposable.addDisposable(addedDisposable)
					observer = incomingObserver
				}

				producer.startWithSignal { _ in }
				expect(addedDisposable.disposed) == false

				observer.sendCompleted()
				expect(addedDisposable.disposed) == true
			}

			it("should dispose of added disposables upon error") {
				let addedDisposable = SimpleDisposable()
				var observer: Signal<Int, TestError>.Observer!

				let producer = SignalProducer<Int, TestError>() { incomingObserver, disposable in
					disposable.addDisposable(addedDisposable)
					observer = incomingObserver
				}

				producer.startWithSignal { _ in }
				expect(addedDisposable.disposed) == false

				observer.sendFailed(.Default)
				expect(addedDisposable.disposed) == true
			}
		}

		describe("start") {
			it("should immediately begin sending events") {
				let producer = SignalProducer<Int, NoError>(values: [1, 2])

				var values: [Int] = []
				var completed = false
				producer.start { event in
					switch event {
					case let .Next(value):
						values.append(value)
					case .Completed:
						completed = true
					default:
						break
					}
				}

				expect(values) == [1, 2]
				expect(completed) == true
			}

			it("should send interrupted if disposed") {
				let producer = SignalProducer<(), NoError>.never

				var interrupted = false
				let disposable = producer.startWithInterrupted {
					interrupted = true
				}

				expect(interrupted) == false

				disposable.dispose()
				expect(interrupted) == true
			}

			it("should release observer when disposed") {
				weak var objectRetainedByObserver: NSObject?
				var disposable: Disposable!
				let test = {
					let producer = SignalProducer<Int, NoError>.never
					let object = NSObject()
					objectRetainedByObserver = object
					disposable = producer.startWithNext { _ in object }
				}

				test()
				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			describe("trailing closure") {
				it("receives next values") {
					let (producer, observer) = SignalProducer<Int, NoError>.pipe()

					var values = [Int]()
					producer.startWithNext { next in
						values.append(next)
					}

					observer.sendNext(1)
					observer.sendNext(2)
					observer.sendNext(3)

					observer.sendCompleted()

					expect(values) == [1, 2, 3]
				}

				// TODO: remove when the method is marked unavailable.
				it("receives next values with erroring signal") {
					let (producer, observer) = SignalProducer<Int, TestError>.pipe()

					var values = [Int]()
					producer.startWithNext { next in
						values.append(next)
					}

					observer.sendNext(1)
					observer.sendNext(2)
					observer.sendNext(3)

					observer.sendCompleted()

					expect(values) == [1, 2, 3]
				}

				it("receives results") {
					let (producer, observer) = SignalProducer<Int, TestError>.pipe()

					var results: [Result<Int, TestError>] = []
					producer.startWithResult { results.append($0) }

					observer.sendNext(1)
					observer.sendNext(2)
					observer.sendNext(3)
					observer.sendFailed(.Default)

					observer.sendCompleted()

					expect(results).to(haveCount(4))
					expect(results[0].value) == 1
					expect(results[1].value) == 2
					expect(results[2].value) == 3
					expect(results[3].error) == .Default
				}
			}
		}

		describe("lift") {
			describe("over unary operators") {
				it("should invoke transformation once per started signal") {
					let baseProducer = SignalProducer<Int, NoError>(values: [1, 2])

					var counter = 0
					let transform = { (signal: Signal<Int, NoError>) -> Signal<Int, NoError> in
						counter += 1
						return signal
					}

					let producer = baseProducer.lift(transform)
					expect(counter) == 0

					producer.start()
					expect(counter) == 1

					producer.start()
					expect(counter) == 2
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, NoError>(values: [1, 2, 3, 4])

					let producer = baseProducer.lift { signal in
						return signal.map { $0 * $0 }
					}
					let result = producer.collect().single()

					expect(result?.value) == [1, 4, 9, 16]
				}
			}

			describe("over binary operators") {
				it("should invoke transformation once per started signal") {
					let baseProducer = SignalProducer<Int, NoError>(values: [1, 2])
					let otherProducer = SignalProducer<Int, NoError>(values: [3, 4])

					var counter = 0
					let transform = { (signal: Signal<Int, NoError>) -> Signal<Int, NoError> -> Signal<(Int, Int), NoError> in
						return { otherSignal in
							counter += 1
							return zip(signal, otherSignal)
						}
					}

					let producer = baseProducer.lift(transform)(otherProducer)
					expect(counter) == 0

					producer.start()
					expect(counter) == 1

					producer.start()
					expect(counter) == 2
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, NoError>(values: [1, 2, 3])
					let otherProducer = SignalProducer<Int, NoError>(values: [4, 5, 6])

					let transform = { (signal: Signal<Int, NoError>) -> Signal<Int, NoError> -> Signal<Int, NoError> in
						return { otherSignal in
							return zip(signal, otherSignal).map { first, second in first + second }
						}
					}

					let producer = baseProducer.lift(transform)(otherProducer)
					let result = producer.collect().single()

					expect(result?.value) == [5, 7, 9]
				}
			}

			describe("over binary operators with signal") {
				it("should invoke transformation once per started signal") {
					let baseProducer = SignalProducer<Int, NoError>(values: [1, 2])
					let (otherSignal, otherSignalObserver) = Signal<Int, NoError>.pipe()

					var counter = 0
					let transform = { (signal: Signal<Int, NoError>) -> Signal<Int, NoError> -> Signal<(Int, Int), NoError> in
						return { otherSignal in
							counter += 1
							return zip(signal, otherSignal)
						}
					}

					let producer = baseProducer.lift(transform)(otherSignal)
					expect(counter) == 0

					producer.start()
					otherSignalObserver.sendNext(1)
					expect(counter) == 1

					producer.start()
					otherSignalObserver.sendNext(2)
					expect(counter) == 2
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, NoError>(values: [ 1, 2, 3 ])
					let (otherSignal, otherSignalObserver) = Signal<Int, NoError>.pipe()

					let transform = { (signal: Signal<Int, NoError>) -> Signal<Int, NoError> -> Signal<Int, NoError> in
						return { otherSignal in
							return zip(signal, otherSignal).map(+)
						}
					}

					let producer = baseProducer.lift(transform)(otherSignal)
					var result: [Int] = []
					var completed: Bool = false

					producer.start { event in
						switch event {
						case .Next(let value): result.append(value)
						case .Completed: completed = true
						default: break
						}
					}

					otherSignalObserver.sendNext(4)
					expect(result) == [ 5 ]

					otherSignalObserver.sendNext(5)
					expect(result) == [ 5, 7 ]

					otherSignalObserver.sendNext(6)
					expect(result) == [ 5, 7, 9 ]
					expect(completed) == true
				}
			}
		}
		
		describe("sequence operators") {
			var producerA: SignalProducer<Int, NoError>!
			var producerB: SignalProducer<Int, NoError>!
			
			beforeEach {
				producerA = SignalProducer<Int, NoError>(values: [ 1, 2 ])
				producerB = SignalProducer<Int, NoError>(values: [ 3, 4 ])
			}
			
			it("should combine the events to one array") {
				let producer = combineLatest([producerA, producerB])
				let result = producer.collect().single()
				
				expect(result?.value) == [[1, 4], [2, 4]]
			}
			
			it("should zip the events to one array") {
				let producer = zip([producerA, producerB])
				let result = producer.collect().single()
				
				expect(result?.value) == [[1, 3], [2, 4]]
			}
		}

		describe("timer") {
			it("should send the current date at the given interval") {
				let scheduler = TestScheduler()
				let producer = timer(1, onScheduler: scheduler, withLeeway: 0)

				let startDate = scheduler.currentDate
				let tick1 = startDate.dateByAddingTimeInterval(1)
				let tick2 = startDate.dateByAddingTimeInterval(2)
				let tick3 = startDate.dateByAddingTimeInterval(3)

				var dates: [NSDate] = []
				producer.startWithNext { dates.append($0) }

				scheduler.advanceByInterval(0.9)
				expect(dates) == []

				scheduler.advanceByInterval(1)
				expect(dates) == [tick1]

				scheduler.advance()
				expect(dates) == [tick1]

				scheduler.advanceByInterval(0.2)
				expect(dates) == [tick1, tick2]

				scheduler.advanceByInterval(1)
				expect(dates) == [tick1, tick2, tick3]
			}

			it("should release the signal when disposed") {
				let scheduler = TestScheduler()
				let producer = timer(1, onScheduler: scheduler, withLeeway: 0)

				weak var weakSignal: Signal<NSDate, NoError>?
				producer.startWithSignal { signal, disposable in
					weakSignal = signal
					scheduler.schedule {
						disposable.dispose()
					}
				}

				expect(weakSignal).toNot(beNil())

				scheduler.run()
				expect(weakSignal).to(beNil())
			}
		}

		describe("on") {
			it("should attach event handlers to each started signal") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()

				var started = 0
				var event = 0
				var next = 0
				var completed = 0
				var terminated = 0

				let producer = baseProducer
					.on(started: {
						started += 1
					}, event: { e in
						event += 1
					}, next: { n in
						next += 1
					}, completed: {
						completed += 1
					}, terminated: {
						terminated += 1
					})

				producer.start()
				expect(started) == 1

				producer.start()
				expect(started) == 2

				observer.sendNext(1)
				expect(event) == 2
				expect(next) == 2

				observer.sendCompleted()
				expect(event) == 4
				expect(completed) == 2
				expect(terminated) == 2
			}

			it("should attach event handlers for disposal") {
				let (baseProducer, _) = SignalProducer<Int, TestError>.pipe()

				var disposed: Bool = false

				let producer = baseProducer
					.on(disposed: { disposed = true })

				let disposable = producer.start()

				expect(disposed) == false
				disposable.dispose()
				expect(disposed) == true
			}
		}

		describe("startOn") {
			it("should invoke effects on the given scheduler") {
				let scheduler = TestScheduler()
				var invoked = false

				let producer = SignalProducer<Int, NoError>() { _ in
					invoked = true
				}

				producer.startOn(scheduler).start()
				expect(invoked) == false

				scheduler.advance()
				expect(invoked) == true
			}

			it("should forward events on their original scheduler") {
				let startScheduler = TestScheduler()
				let testScheduler = TestScheduler()

				let producer = timer(2, onScheduler: testScheduler, withLeeway: 0)

				var next: NSDate?
				producer.startOn(startScheduler).startWithNext { next = $0 }

				startScheduler.advanceByInterval(2)
				expect(next).to(beNil())

				testScheduler.advanceByInterval(1)
				expect(next).to(beNil())

				testScheduler.advanceByInterval(1)
				expect(next) == testScheduler.currentDate
			}
		}

		describe("flatMapError") {
			it("should invoke the handler and start new producer for an error") {
				let (baseProducer, baseObserver) = SignalProducer<Int, TestError>.pipe()

				var values: [Int] = []
				var completed = false

				baseProducer
					.flatMapError { (error: TestError) -> SignalProducer<Int, TestError> in
						expect(error) == TestError.Default
						expect(values) == [1]

						return .init(value: 2)
					}
					.start { event in
						switch event {
						case let .Next(value):
							values.append(value)
						case .Completed:
							completed = true
						default:
							break
						}
					}

				baseObserver.sendNext(1)
				baseObserver.sendFailed(.Default)

				expect(values) == [1, 2]
				expect(completed) == true
			}

			it("should interrupt the replaced producer on disposal") {
				let (baseProducer, baseObserver) = SignalProducer<Int, TestError>.pipe()

				var (disposed, interrupted) = (false, false)
				let disposable = baseProducer
					.flatMapError { (error: TestError) -> SignalProducer<Int, TestError> in
						return SignalProducer<Int, TestError> { _, disposable in
							disposable += ActionDisposable { disposed = true }
						}
					}
					.startWithInterrupted { interrupted = true }

				baseObserver.sendFailed(.Default)
				disposable.dispose()

				expect(interrupted) == true
				expect(disposed) == true
			}
		}

		describe("flatten") {
			describe("FlattenStrategy.Concat") {
				describe("sequencing") {
					var completePrevious: (() -> Void)!
					var sendSubsequent: (() -> Void)!
					var completeOuter: (() -> Void)!

					var subsequentStarted = false

					beforeEach {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, NoError>, NoError>.pipe()
						let (previousProducer, previousObserver) = SignalProducer<Int, NoError>.pipe()

						subsequentStarted = false
						let subsequentProducer = SignalProducer<Int, NoError> { _ in
							subsequentStarted = true
						}

						completePrevious = { previousObserver.sendCompleted() }
						sendSubsequent = { outerObserver.sendNext(subsequentProducer) }
						completeOuter = { outerObserver.sendCompleted() }

						outerProducer.flatten(.Concat).start()
						outerObserver.sendNext(previousProducer)
					}

					it("should immediately start subsequent inner producer if previous inner producer has already completed") {
						completePrevious()
						sendSubsequent()
						expect(subsequentStarted) == true
					}

					context("with queued producers") {
						beforeEach {
							// Place the subsequent producer into `concat`'s queue.
							sendSubsequent()
							expect(subsequentStarted) == false
						}

						it("should start subsequent inner producer upon completion of previous inner producer") {
							completePrevious()
							expect(subsequentStarted) == true
						}

						it("should start subsequent inner producer upon completion of previous inner producer and completion of outer producer") {
							completeOuter()
							completePrevious()
							expect(subsequentStarted) == true
						}
					}
				}

				it("should forward an error from an inner producer") {
					let errorProducer = SignalProducer<Int, TestError>(error: TestError.Default)
					let outerProducer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: errorProducer)

					var error: TestError?
					(outerProducer.flatten(.Concat)).startWithFailed { e in
						error = e
					}

					expect(error) == TestError.Default
				}

				it("should forward an error from the outer producer") {
					let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()

					var error: TestError?
					outerProducer.flatten(.Concat).startWithFailed { e in
						error = e
					}

					outerObserver.sendFailed(TestError.Default)
					expect(error) == TestError.Default
				}

				describe("completion") {
					var completeOuter: (() -> Void)!
					var completeInner: (() -> Void)!

					var completed = false

					beforeEach {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, NoError>, NoError>.pipe()
						let (innerProducer, innerObserver) = SignalProducer<Int, NoError>.pipe()

						completeOuter = { outerObserver.sendCompleted() }
						completeInner = { innerObserver.sendCompleted() }

						completed = false
						outerProducer.flatten(.Concat).startWithCompleted {
							completed = true
						}

						outerObserver.sendNext(innerProducer)
					}

					it("should complete when inner producers complete, then outer producer completes") {
						completeInner()
						expect(completed) == false

						completeOuter()
						expect(completed) == true
					}

					it("should complete when outer producers completes, then inner producers complete") {
						completeOuter()
						expect(completed) == false

						completeInner()
						expect(completed) == true
					}
				}
			}

			describe("FlattenStrategy.Merge") {
				describe("behavior") {
					var completeA: (() -> Void)!
					var sendA: (() -> Void)!
					var completeB: (() -> Void)!
					var sendB: (() -> Void)!

					var outerCompleted = false

					var recv = [Int]()

					beforeEach {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, NoError>, NoError>.pipe()
						let (producerA, observerA) = SignalProducer<Int, NoError>.pipe()
						let (producerB, observerB) = SignalProducer<Int, NoError>.pipe()

						completeA = { observerA.sendCompleted() }
						completeB = { observerB.sendCompleted() }

						var a = 0
						sendA = { observerA.sendNext(a); a += 1 }

						var b = 100
						sendB = { observerB.sendNext(b); b += 1 }

						outerProducer.flatten(.Merge).start { event in
							switch event {
							case let .Next(i):
								recv.append(i)
							case .Completed:
								outerCompleted = true
							default:
								break
							}
						}

						outerObserver.sendNext(producerA)
						outerObserver.sendNext(producerB)

						outerObserver.sendCompleted()
					}

					it("should forward values from any inner signals") {
						sendA()
						sendA()
						sendB()
						sendA()
						sendB()
						expect(recv) == [0, 1, 100, 2, 101]
					}

					it("should complete when all signals have completed") {
						completeA()
						expect(outerCompleted) == false
						completeB()
						expect(outerCompleted) == true
					}
				}

				describe("error handling") {
					it("should forward an error from an inner signal") {
						let errorProducer = SignalProducer<Int, TestError>(error: TestError.Default)
						let outerProducer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: errorProducer)

						var error: TestError?
						outerProducer.flatten(.Merge).startWithFailed { e in
							error = e
						}
						expect(error) == TestError.Default
					}

					it("should forward an error from the outer signal") {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()

						var error: TestError?
						outerProducer.flatten(.Merge).startWithFailed { e in
							error = e
						}

						outerObserver.sendFailed(TestError.Default)
						expect(error) == TestError.Default
					}
				}
			}

			describe("FlattenStrategy.Latest") {
				it("should forward values from the latest inner signal") {
					let (outer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()
					let (firstInner, firstInnerObserver) = SignalProducer<Int, TestError>.pipe()
					let (secondInner, secondInnerObserver) = SignalProducer<Int, TestError>.pipe()

					var receivedValues: [Int] = []
					var errored = false
					var completed = false

					outer.flatten(.Latest).start { event in
						switch event {
						case let .Next(value):
							receivedValues.append(value)
						case .Completed:
							completed = true
						case .Failed:
							errored = true
						case .Interrupted:
							break
						}
					}

					outerObserver.sendNext(SignalProducer(value: 0))
					outerObserver.sendNext(firstInner)
					firstInnerObserver.sendNext(1)
					outerObserver.sendNext(secondInner)
					secondInnerObserver.sendNext(2)
					outerObserver.sendCompleted()

					expect(receivedValues) == [ 0, 1, 2 ]
					expect(errored) == false
					expect(completed) == false

					firstInnerObserver.sendNext(3)
					firstInnerObserver.sendCompleted()
					secondInnerObserver.sendNext(4)
					secondInnerObserver.sendCompleted()

					expect(receivedValues) == [ 0, 1, 2, 4 ]
					expect(errored) == false
					expect(completed) == true
				}

				it("should forward an error from an inner signal") {
					let inner = SignalProducer<Int, TestError>(error: .Default)
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					let result = outer.flatten(.Latest).first()
					expect(result?.error) == TestError.Default
				}

				it("should forward an error from the outer signal") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(error: .Default)

					let result = outer.flatten(.Latest).first()
					expect(result?.error) == TestError.Default
				}

				it("should complete when the original and latest signals have completed") {
					let inner = SignalProducer<Int, TestError>.empty
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.Latest).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should complete when the outer signal completes before sending any signals") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>.empty

					var completed = false
					outer.flatten(.Latest).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should not deadlock") {
					let producer = SignalProducer<Int, NoError>(value: 1)
						.flatMap(.Latest) { _ in SignalProducer(value: 10) }

					let result = producer.take(1).last()
					expect(result?.value) == 10
				}
			}

			describe("interruption") {
				var innerObserver: Signal<(), NoError>.Observer!
				var outerObserver: Signal<SignalProducer<(), NoError>, NoError>.Observer!
				var execute: (FlattenStrategy -> Void)!

				var interrupted = false
				var completed = false

				beforeEach {
					let (innerProducer, incomingInnerObserver) = SignalProducer<(), NoError>.pipe()
					let (outerProducer, incomingOuterObserver) = SignalProducer<SignalProducer<(), NoError>, NoError>.pipe()

					innerObserver = incomingInnerObserver
					outerObserver = incomingOuterObserver

					execute = { strategy in
						interrupted = false
						completed = false

						outerProducer
							.flatten(strategy)
							.start { event in
								switch event {
								case .Interrupted:
									interrupted = true
								case .Completed:
									completed = true
								default:
									break
								}
							}
					}

					incomingOuterObserver.sendNext(innerProducer)
				}

				describe("Concat") {
					it("should drop interrupted from an inner producer") {
						execute(.Concat)

						innerObserver.sendInterrupted()
						expect(interrupted) == false
						expect(completed) == false

						outerObserver.sendCompleted()
						expect(completed) == true
					}

					it("should forward interrupted from the outer producer") {
						execute(.Concat)
						outerObserver.sendInterrupted()
						expect(interrupted) == true
					}
				}

				describe("Latest") {
					it("should drop interrupted from an inner producer") {
						execute(.Latest)

						innerObserver.sendInterrupted()
						expect(interrupted) == false
						expect(completed) == false

						outerObserver.sendCompleted()
						expect(completed) == true
					}

					it("should forward interrupted from the outer producer") {
						execute(.Latest)
						outerObserver.sendInterrupted()
						expect(interrupted) == true
					}
				}

				describe("Merge") {
					it("should drop interrupted from an inner producer") {
						execute(.Merge)

						innerObserver.sendInterrupted()
						expect(interrupted) == false
						expect(completed) == false

						outerObserver.sendCompleted()
						expect(completed) == true
					}

					it("should forward interrupted from the outer producer") {
						execute(.Merge)
						outerObserver.sendInterrupted()
						expect(interrupted) == true
					}
				}
			}

			describe("disposal") {
				var completeOuter: (() -> Void)!
				var disposeOuter: (() -> Void)!
				var execute: (FlattenStrategy -> Void)!

				var innerDisposable = SimpleDisposable()
				var interrupted = false

				beforeEach {
					execute = { strategy in
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, NoError>, NoError>.pipe()

						innerDisposable = SimpleDisposable()
						let innerProducer = SignalProducer<Int, NoError> { $1.addDisposable(innerDisposable) }
						
						interrupted = false
						let outerDisposable = outerProducer.flatten(strategy).startWithInterrupted {
							interrupted = true
						}

						completeOuter = outerObserver.sendCompleted
						disposeOuter = outerDisposable.dispose

						outerObserver.sendNext(innerProducer)
					}
				}
				
				describe("Concat") {
					it("should cancel inner work when disposed before the outer producer completes") {
						execute(.Concat)

						expect(innerDisposable.disposed) == false
						expect(interrupted) == false
						disposeOuter()

						expect(innerDisposable.disposed) == true
						expect(interrupted) == true
					}

					it("should cancel inner work when disposed after the outer producer completes") {
						execute(.Concat)

						completeOuter()

						expect(innerDisposable.disposed) == false
						expect(interrupted) == false
						disposeOuter()

						expect(innerDisposable.disposed) == true
						expect(interrupted) == true
					}
				}

				describe("Latest") {
					it("should cancel inner work when disposed before the outer producer completes") {
						execute(.Latest)

						expect(innerDisposable.disposed) == false
						expect(interrupted) == false
						disposeOuter()

						expect(innerDisposable.disposed) == true
						expect(interrupted) == true
					}

					it("should cancel inner work when disposed after the outer producer completes") {
						execute(.Latest)

						completeOuter()

						expect(innerDisposable.disposed) == false
						expect(interrupted) == false
						disposeOuter()

						expect(innerDisposable.disposed) == true
						expect(interrupted) == true
					}
				}

				describe("Merge") {
					it("should cancel inner work when disposed before the outer producer completes") {
						execute(.Merge)

						expect(innerDisposable.disposed) == false
						expect(interrupted) == false
						disposeOuter()

						expect(innerDisposable.disposed) == true
						expect(interrupted) == true
					}

					it("should cancel inner work when disposed after the outer producer completes") {
						execute(.Merge)

						completeOuter()

						expect(innerDisposable.disposed) == false
						expect(interrupted) == false
						disposeOuter()

						expect(innerDisposable.disposed) == true
						expect(interrupted) == true
					}
				}
			}
		}

		describe("times") {
			it("should start a signal N times upon completion") {
				let original = SignalProducer<Int, NoError>(values: [ 1, 2, 3 ])
				let producer = original.times(3)

				let result = producer.collect().single()
				expect(result?.value) == [ 1, 2, 3, 1, 2, 3, 1, 2, 3 ]
			}

			it("should produce an equivalent signal producer if count is 1") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original.times(1)

				let result = producer.collect().single()
				expect(result?.value) == [ 1 ]
			}

			it("should produce an empty signal if count is 0") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original.times(0)

				let result = producer.first()
				expect(result).to(beNil())
			}

			it("should not repeat upon error") {
				let results: [Result<Int, TestError>] = [
					.Success(1),
					.Success(2),
					.Failure(.Default)
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.times(3)

				let events = producer
					.materialize()
					.collect()
					.single()
				let result = events?.value

				let expectedEvents: [Event<Int, TestError>] = [
					.Next(1),
					.Next(2),
					.Failed(.Default)
				]

				// TODO: if let result = result where result.count == expectedEvents.count
				if result?.count != expectedEvents.count {
					fail("Invalid result: \(result)")
				} else {
					// Can't test for equality because Array<T> is not Equatable,
					// and neither is Event<Value, Error>.
					expect(result![0] == expectedEvents[0]) == true
					expect(result![1] == expectedEvents[1]) == true
					expect(result![2] == expectedEvents[2]) == true
				}
			}

			it("should evaluate lazily") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original.times(Int.max)

				let result = producer.take(1).single()
				expect(result?.value) == 1
			}
		}

		describe("retry") {
			it("should start a signal N times upon error") {
				let results: [Result<Int, TestError>] = [
					.Failure(.Error1),
					.Failure(.Error2),
					.Success(1)
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.retry(2)

				let result = producer.single()

				expect(result?.value) == 1
			}

			it("should forward errors that occur after all retries") {
				let results: [Result<Int, TestError>] = [
					.Failure(.Default),
					.Failure(.Error1),
					.Failure(.Error2),
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.retry(2)

				let result = producer.single()

				expect(result?.error) == TestError.Error2
			}

			it("should not retry upon completion") {
				let results: [Result<Int, TestError>] = [
					.Success(1),
					.Success(2),
					.Success(3)
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.retry(2)

				let result = producer.single()
				expect(result?.value) == 1
			}
		}

		describe("then") {
			it("should start the subsequent producer after the completion of the original") {
				let (original, observer) = SignalProducer<Int, NoError>.pipe()

				var subsequentStarted = false
				let subsequent = SignalProducer<Int, NoError> { observer, _ in
					subsequentStarted = true
				}

				let producer = original.then(subsequent)
				producer.start()
				expect(subsequentStarted) == false

				observer.sendCompleted()
				expect(subsequentStarted) == true
			}

			it("should forward errors from the original producer") {
				let original = SignalProducer<Int, TestError>(error: .Default)
				let subsequent = SignalProducer<Int, TestError>.empty

				let result = original.then(subsequent).first()
				expect(result?.error) == TestError.Default
			}

			it("should forward errors from the subsequent producer") {
				let original = SignalProducer<Int, TestError>.empty
				let subsequent = SignalProducer<Int, TestError>(error: .Default)

				let result = original.then(subsequent).first()
				expect(result?.error) == TestError.Default
			}

			it("should forward interruptions from the original producer") {
				let (original, observer) = SignalProducer<Int, NoError>.pipe()

				var subsequentStarted = false
				let subsequent = SignalProducer<Int, NoError> { observer, _ in
					subsequentStarted = true
				}

				var interrupted = false
				let producer = original.then(subsequent)
				producer.startWithInterrupted {
					interrupted = true
				}
				expect(subsequentStarted) == false

				observer.sendInterrupted()
				expect(interrupted) == true
			}

			it("should complete when both inputs have completed") {
				let (original, originalObserver) = SignalProducer<Int, NoError>.pipe()
				let (subsequent, subsequentObserver) = SignalProducer<String, NoError>.pipe()

				let producer = original.then(subsequent)

				var completed = false
				producer.startWithCompleted {
					completed = true
				}

				originalObserver.sendCompleted()
				expect(completed) == false

				subsequentObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("first") {
			it("should start a signal then block on the first value") {
				let (_signal, observer) = Signal<Int, NoError>.pipe()
				let queue = dispatch_queue_create("\(#file):\(#line)", DISPATCH_QUEUE_SERIAL)
				let producer = SignalProducer(signal: _signal.delay(0.1, onScheduler: QueueScheduler(queue: queue)))

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.first()
				}
				expect(result).to(beNil())

				observer.sendNext(1)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value) == 1
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty.first()
				expect(result).to(beNil())
			}

			it("should return the first value if more than one value is sent") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]).first()
				expect(result?.value) == 1
			}

			it("should return an error if one occurs before the first value") {
				let result = SignalProducer<Int, TestError>(error: .Default).first()
				expect(result?.error) == TestError.Default
			}
		}

		describe("single") {
			it("should start a signal then block until completion") {
				let (_signal, observer) = Signal<Int, NoError>.pipe()
				let queue = dispatch_queue_create("\(#file):\(#line)", DISPATCH_QUEUE_SERIAL)
				let producer = SignalProducer(signal: _signal.delay(0.1, onScheduler: QueueScheduler(queue: queue)))

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.single()
				}
				expect(result).to(beNil())

				observer.sendNext(1)
				expect(result).to(beNil())

				observer.sendCompleted()
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value) == 1
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty.single()
				expect(result).to(beNil())
			}

			it("should return a nil result if more than one value is sent before completion") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]).single()
				expect(result).to(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default).single()
				expect(result?.error) == TestError.Default
			}
		}

		describe("last") {
			it("should start a signal then block until completion") {
				let (_signal, observer) = Signal<Int, NoError>.pipe()
				let queue = dispatch_queue_create("\(#file):\(#line)", DISPATCH_QUEUE_SERIAL)
				let producer = SignalProducer(signal: _signal.delay(0.1, onScheduler: QueueScheduler(queue: queue)))

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.last()
				}
				expect(result).to(beNil())

				observer.sendNext(1)
				observer.sendNext(2)
				expect(result).to(beNil())

				observer.sendCompleted()
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value) == 2
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty.last()
				expect(result).to(beNil())
			}

			it("should return the last value if more than one value is sent") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]).last()
				expect(result?.value) == 2
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default).last()
				expect(result?.error) == TestError.Default
			}
		}

		describe("wait") {
			it("should start a signal then block until completion") {
				let (_signal, observer) = Signal<Int, NoError>.pipe()
				let queue = dispatch_queue_create("\(#file):\(#line)", DISPATCH_QUEUE_SERIAL)
				let producer = SignalProducer(signal: _signal.delay(0.1, onScheduler: QueueScheduler(queue: queue)))

				var result: Result<(), NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.wait()
				}
				expect(result).to(beNil())

				observer.sendCompleted()
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).toNot(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default).wait()
				expect(result.error) == TestError.Default
			}
		}

		describe("observeOn") {
			it("should immediately cancel upstream producer's work when disposed") {
				var upstreamDisposable: Disposable!
				let producer = SignalProducer<(), NoError>{ _, innerDisposable in
					upstreamDisposable = innerDisposable
				}

				var downstreamDisposable: Disposable!
				producer
					.observeOn(TestScheduler())
					.startWithSignal { signal, innerDisposable in
						downstreamDisposable = innerDisposable
					}
				
				expect(upstreamDisposable.disposed) == false
				
				downstreamDisposable.dispose()
				expect(upstreamDisposable.disposed) == true
			}
		}

		describe("take") {
			it("Should not start concat'ed producer if the first one sends a value when using take(1)") {
				let scheduler: QueueScheduler
				if #available(OSX 10.10, *) {
					scheduler = QueueScheduler()
				} else {
					scheduler = QueueScheduler(queue: dispatch_get_main_queue())
				}

				// Delaying producer1 from sending a value to test whether producer2 is started in the mean-time.
				let producer1 = SignalProducer<Int, NoError>() { handler, _ in
					handler.sendNext(1)
					handler.sendCompleted()
				}.startOn(scheduler)

				var started = false
				let producer2 = SignalProducer<Int, NoError>() { handler, _ in
					started = true
					handler.sendNext(2)
					handler.sendCompleted()
				}

				let result = producer1.concat(producer2).take(1).collect().first()

				expect(result?.value) == [1]
				expect(started) == false
			}
		}

		describe("replayLazily") {
			var producer: SignalProducer<Int, TestError>!
			var observer: SignalProducer<Int, TestError>.ProducedSignal.Observer!

			var replayedProducer: SignalProducer<Int, TestError>!

			beforeEach {
				let (producerTemp, observerTemp) = SignalProducer<Int, TestError>.pipe()
				producer = producerTemp
				observer = observerTemp

				replayedProducer = producer.replayLazily(2)
			}

			context("subscribing to underlying producer") {
				it("emits new values") {
					var last: Int?

					replayedProducer
						.assumeNoErrors()
						.startWithNext { last = $0 }
					
					expect(last).to(beNil())

					observer.sendNext(1)
					expect(last) == 1

					observer.sendNext(2)
					expect(last) == 2
				}

				it("emits errors") {
					var error: TestError?

					replayedProducer.startWithFailed { error = $0 }
					expect(error).to(beNil())

					observer.sendFailed(.Default)
					expect(error) == TestError.Default
				}
			}

			context("buffers past values") {
				it("emits last value upon subscription") {
					let disposable = replayedProducer
						.start()

					observer.sendNext(1)
					disposable.dispose()

					var last: Int?

					replayedProducer
						.assumeNoErrors()
						.startWithNext { last = $0 }
					expect(last) == 1
				}

				it("emits previous failure upon subscription") {
					let disposable = replayedProducer
						.start()

					observer.sendFailed(.Default)
					disposable.dispose()

					var error: TestError?

					replayedProducer
						.startWithFailed { error = $0 }
					expect(error) == TestError.Default
				}

				it("emits last n values upon subscription") {
					var disposable = replayedProducer
						.start()

					observer.sendNext(1)
					observer.sendNext(2)
					observer.sendNext(3)
					observer.sendNext(4)
					disposable.dispose()

					var values: [Int] = []

					disposable = replayedProducer
						.assumeNoErrors()
						.startWithNext { values.append($0) }
					expect(values) == [ 3, 4 ]

					observer.sendNext(5)
					expect(values) == [ 3, 4, 5 ]

					disposable.dispose()
					values = []

					replayedProducer
						.assumeNoErrors()
						.startWithNext { values.append($0) }
					expect(values) == [ 4, 5 ]
				}
			}

			context("starting underying producer") {
				it("starts lazily") {
					var started = false

					let producer = SignalProducer<Int, NoError>(value: 0)
						.on(started: { started = true })
					expect(started) == false

					let replayedProducer = producer
						.replayLazily(1)
					expect(started) == false

					replayedProducer.start()
					expect(started) == true
				}

				it("shares a single subscription") {
					var startedTimes = 0

					let producer = SignalProducer<Int, NoError>.never
						.on(started: { startedTimes += 1 })
					expect(startedTimes) == 0

					let replayedProducer = producer
						.replayLazily(1)
					expect(startedTimes) == 0

					replayedProducer.start()
					expect(startedTimes) == 1

					replayedProducer.start()
					expect(startedTimes) == 1
				}

				it("does not start multiple times when subscribing multiple times") {
					var startedTimes = 0

					let producer = SignalProducer<Int, NoError>(value: 0)
						.on(started: { startedTimes += 1 })

					let replayedProducer = producer
						.replayLazily(1)

					expect(startedTimes) == 0
					replayedProducer.start().dispose()
					expect(startedTimes) == 1
					replayedProducer.start().dispose()
					expect(startedTimes) == 1
				}

				it("does not start again if it finished") {
					var startedTimes = 0

					let producer = SignalProducer<Int, NoError>.empty
						.on(started: { startedTimes += 1 })
					expect(startedTimes) == 0

					let replayedProducer = producer
						.replayLazily(1)
					expect(startedTimes) == 0

					replayedProducer.start()
					expect(startedTimes) == 1

					replayedProducer.start()
					expect(startedTimes) == 1
				}
			}

			context("lifetime") {
				it("does not dispose underlying subscription if the replayed producer is still in memory") {
					var disposed = false

					let producer = SignalProducer<Int, NoError>.never
						.on(disposed: { disposed = true })

					let replayedProducer = producer
						.replayLazily(1)

					expect(disposed) == false
					let disposable = replayedProducer.start()
					expect(disposed) == false

					disposable.dispose()
					expect(disposed) == false
				}
				
				it("does not dispose if it has active subscriptions") {
					var disposed = false

					let producer = SignalProducer<Int, NoError>.never
						.on(disposed: { disposed = true })

					var replayedProducer = ImplicitlyUnwrappedOptional(producer.replayLazily(1))

					expect(disposed) == false
					let disposable1 = replayedProducer.start()
					let disposable2 = replayedProducer.start()
					expect(disposed) == false

					replayedProducer = nil
					expect(disposed) == false

					disposable1.dispose()
					expect(disposed) == false
					
					disposable2.dispose()
					expect(disposed) == true
				}

				it("disposes underlying producer when the producer is deallocated") {
					var disposed = false

					let producer = SignalProducer<Int, NoError>.never
						.on(disposed: { disposed = true })

					var replayedProducer = ImplicitlyUnwrappedOptional(producer.replayLazily(1))

					expect(disposed) == false
					let disposable = replayedProducer.start()
					expect(disposed) == false

					disposable.dispose()
					expect(disposed) == false

					replayedProducer = nil
					expect(disposed) == true
				}

				it("does not leak buffered values") {
					final class Value {
						private let deinitBlock: () -> Void

						init(deinitBlock: () -> Void) {
							self.deinitBlock = deinitBlock
						}

						deinit {
							self.deinitBlock()
						}
					}

					var deinitValues = 0

					var producer: SignalProducer<Value, NoError>! = SignalProducer(value: Value {
						deinitValues += 1
					})
					expect(deinitValues) == 0

					var replayedProducer: SignalProducer<Value, NoError>! = producer
						.replayLazily(1)
					
					let disposable = replayedProducer
						.start()
					
					disposable.dispose()
					expect(deinitValues) == 0
					
					producer = nil
					expect(deinitValues) == 0
					
					replayedProducer = nil
					expect(deinitValues) == 1
				}
			}
			
			describe("log events") {
				it("should output the correct event") {
					let expectations: [String -> Void] = [
						{ event in expect(event) == "[] Started" },
						{ event in expect(event) == "[] Next 1" },
						{ event in expect(event) == "[] Completed" },
						{ event in expect(event) == "[] Terminated" },
						{ event in expect(event) == "[] Disposed" }
					]
					
					let logger = TestLogger(expectations: expectations)
					
					let (producer, observer) = SignalProducer<Int, TestError>.pipe()
					producer
						.logEvents(logger: logger.logEvent)
						.start()
					
					observer.sendNext(1)
					observer.sendCompleted()
				}
			}

			describe("init(values) ambiguity") {
				it("should not be a SignalProducer<SignalProducer<Int, NoError>, NoError>") {

					let producer1: SignalProducer<Int, NoError> = SignalProducer.empty
					let producer2: SignalProducer<Int, NoError> = SignalProducer.empty

					let producer = SignalProducer(values: [producer1, producer2])
						.flatten(.Merge)

					expect(producer is SignalProducer<Int, NoError>) == true
				}
			}
		}
	}
}

// MARK: - Helpers

extension SignalProducer {
	internal static func pipe() -> (SignalProducer, ProducedSignal.Observer) {
		let (signal, observer) = ProducedSignal.pipe()
		let producer = SignalProducer(signal: signal)
		return (producer, observer)
	}

	/// Creates a producer that can be started as many times as elements in `results`.
	/// Each signal will immediately send either a value or an error.
	private static func attemptWithResults<C: CollectionType where C.Generator.Element == Result<Value, Error>, C.Index.Distance == Int>(results: C) -> SignalProducer<Value, Error> {
		let resultCount = results.count
		var operationIndex = 0

		precondition(resultCount > 0)

		let operation: () -> Result<Value, Error> = {
			if operationIndex < resultCount {
				defer {
					operationIndex += 1
				}

				return results[results.startIndex.advancedBy(operationIndex)]
			} else {
				fail("Operation started too many times")

				return results[results.startIndex.advancedBy(0)]
			}
		}

		return SignalProducer.attempt(operation)
	}
}
