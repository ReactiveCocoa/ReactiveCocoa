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
					handlerCalledTimes++

					return
				}

				signalProducer.start()
				signalProducer.start()

				expect(handlerCalledTimes).to(equal(2))
			}

			it("should release signal observers when given disposable is disposed") {
				var disposable: Disposable!

				let producer = SignalProducer<Int, NoError> { observer, innerDisposable in
					disposable = innerDisposable

					innerDisposable.addDisposable {
						// This is necessary to keep the observer long enough to
						// even test the memory management.
						sendNext(observer, 0)
					}
				}

				weak var objectRetainedByObserver: NSObject?
				producer.startWithSignal { signal, _ in
					let object = NSObject()
					objectRetainedByObserver = object
					signal.observe { _ in object }
				}

				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			it("should dispose of added disposables upon completion") {
				let addedDisposable = SimpleDisposable()
				var sink: Signal<(), NoError>.Observer!

				let producer = SignalProducer<(), NoError>() { observer, disposable in
					disposable.addDisposable(addedDisposable)
					sink = observer
				}

				producer.start()
				expect(addedDisposable.disposed).to(beFalsy())

				sendCompleted(sink)
				expect(addedDisposable.disposed).to(beTruthy())
			}

			it("should dispose of added disposables upon error") {
				let addedDisposable = SimpleDisposable()
				var sink: Signal<(), TestError>.Observer!

				let producer = SignalProducer<(), TestError>() { observer, disposable in
					disposable.addDisposable(addedDisposable)
					sink = observer
				}

				producer.start()
				expect(addedDisposable.disposed).to(beFalsy())

				sendError(sink, .Default)
				expect(addedDisposable.disposed).to(beTruthy())
			}

			it("should dispose of added disposables upon interruption") {
				let addedDisposable = SimpleDisposable()
				var sink: Signal<(), NoError>.Observer!

				let producer = SignalProducer<(), NoError>() { observer, disposable in
					disposable.addDisposable(addedDisposable)
					sink = observer
				}

				producer.start()
				expect(addedDisposable.disposed).to(beFalsy())

				sendInterrupted(sink)
				expect(addedDisposable.disposed).to(beTruthy())
			}

			it("should dispose of added disposables upon start() disposal") {
				let addedDisposable = SimpleDisposable()

				let producer = SignalProducer<(), TestError>() { _, disposable in
					disposable.addDisposable(addedDisposable)
					return
				}

				let startDisposable = producer.start()
				expect(addedDisposable.disposed).to(beFalsy())

				startDisposable.dispose()
				expect(addedDisposable.disposed).to(beTruthy())
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
				let (producer, sink) = SignalProducer<Int, NSError>.buffer()

				sendNext(sink, 1)
				sendNext(sink, 2)
				sendNext(sink, 3)

				var values: [Int] = []
				var completed = false
				producer.start(next: {
					values.append($0)
				}, completed: {
					completed = true
				})

				expect(values).to(equal([1, 2, 3]))
				expect(completed).to(beFalsy())

				sendNext(sink, 4)
				sendNext(sink, 5)

				expect(values).to(equal([1, 2, 3, 4, 5]))
				expect(completed).to(beFalsy())

				sendCompleted(sink)

				expect(values).to(equal([1, 2, 3, 4, 5]))
				expect(completed).to(beTruthy())
			}

			it("should drop earliest events to maintain the capacity") {
				let (producer, sink) = SignalProducer<Int, TestError>.buffer(1)

				sendNext(sink, 1)
				sendNext(sink, 2)

				var values: [Int] = []
				var error: TestError?
				producer.start(next: {
					values.append($0)
				}, error: {
					error = $0
				})
				
				expect(values).to(equal([2]))
				expect(error).to(beNil())

				sendNext(sink, 3)
				sendNext(sink, 4)

				expect(values).to(equal([2, 3, 4]))
				expect(error).to(beNil())

				sendError(sink, .Default)

				expect(values).to(equal([2, 3, 4]))
				expect(error).to(equal(TestError.Default))
			}
			
			it("should always replay termination event") {
				let (producer, sink) = SignalProducer<Int, TestError>.buffer(0)
				var completed = false
				
				sendCompleted(sink)
				
				producer.start(completed: {
					completed = true
				})
				
				expect(completed).to(beTruthy())
			}
			
			it("should replay values after being terminated") {
				let (producer, sink) = SignalProducer<Int, TestError>.buffer(1)
				var value: Int?
				var completed = false
				
				sendNext(sink, 123)
				sendCompleted(sink)
				
				producer.start(next: {val in
					value = val
				}, completed: {
					completed = true
				})
				
				expect(value).to(equal(123))
				expect(completed).to(beTruthy())
			}

			it("should not deadlock when started while sending") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				sendNext(sink, 1)
				sendNext(sink, 2)
				sendNext(sink, 3)

				var values: [Int] = []
				producer.start(completed: {
					values = []

					producer.start(next: { value in
						values.append(value)
					})
				})

				sendCompleted(sink)
				expect(values).to(equal([ 1, 2, 3 ]))
			}

			it("should buffer values before sending recursively to new observers") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var values: [Int] = []
				var lastBufferedValues: [Int] = []

				producer.start(next: { newValue in
					values.append(newValue)

					var bufferedValues: [Int] = []
					
					producer.start(next: { bufferedValue in
						bufferedValues.append(bufferedValue)
					})

					expect(bufferedValues).to(equal(values))
					lastBufferedValues = bufferedValues
				})

				sendNext(sink, 1)
				expect(values).to(equal([ 1 ]))
				expect(lastBufferedValues).to(equal(values))

				sendNext(sink, 2)
				expect(values).to(equal([ 1, 2 ]))
				expect(lastBufferedValues).to(equal(values))

				sendNext(sink, 3)
				expect(values).to(equal([ 1, 2, 3 ]))
				expect(lastBufferedValues).to(equal(values))
			}
		}

		describe("trailing closure") {
			it("receives next values") {
				var values = [Int]()
				let (producer, sink) = SignalProducer<Int, NoError>.buffer(1)
				sendNext(sink, 1)

				producer.start { next in
					values.append(next)
				}

				expect(values).to(equal([1]))
			}
		}

		describe("SignalProducer.attempt") {
			it("should run the operation once per start()") {
				var operationRunTimes = 0
				let operation: () -> Result<String, NSError> = {
					operationRunTimes++

					return .Success("OperationValue")
				}

				SignalProducer.attempt(operation).start()
				SignalProducer.attempt(operation).start()

				expect(operationRunTimes).to(equal(2))
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
						expect(started).to(beFalsy())
						expect(value).to(beNil())
					}

				expect(started).to(beTruthy())
				expect(value).to(equal(42))
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

				expect(addedDisposable.disposed).to(beFalsy())

				disposable.dispose()
				expect(addedDisposable.disposed).to(beTruthy())
			}

			it("should send interrupted if disposed") {
				var interrupted = false
				var disposable: Disposable!

				SignalProducer<Int, NoError>(value: 42)
					.startOn(TestScheduler())
					.startWithSignal { signal, innerDisposable in
						signal.observe(interrupted: {
							interrupted = true
						})

						disposable = innerDisposable
					}

				expect(interrupted).to(beFalsy())

				disposable.dispose()
				expect(interrupted).to(beTruthy())
			}

			it("should release signal observers if disposed") {
				weak var objectRetainedByObserver: NSObject?
				var disposable: Disposable!

				let producer = SignalProducer<Int, NoError>.never
				producer.startWithSignal { signal, innerDisposable in
					let object = NSObject()
					objectRetainedByObserver = object
					signal.observe { _ in object.description }
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
						expect(started).to(beFalsy())
						expect(value).to(beNil())

						disposable.dispose()
					}

				expect(started).to(beFalsy())
				expect(value).to(beNil())
			}

			it("should send interrupted if disposed before closure return") {
				var interrupted = false

				SignalProducer<Int, NoError>(value: 42)
					.startWithSignal { signal, disposable in
						expect(interrupted).to(beFalsy())

						signal.observe(interrupted: {
							interrupted = true
						})

						disposable.dispose()
					}

				expect(interrupted).to(beTruthy())
			}

			it("should dispose of added disposables upon completion") {
				let addedDisposable = SimpleDisposable()
				var sink: Signal<Int, TestError>.Observer!

				let producer = SignalProducer<Int, TestError>() { observer, disposable in
					disposable.addDisposable(addedDisposable)
					sink = observer
				}

				producer.startWithSignal { _ in }
				expect(addedDisposable.disposed).to(beFalsy())

				sendCompleted(sink)
				expect(addedDisposable.disposed).to(beTruthy())
			}

			it("should dispose of added disposables upon error") {
				let addedDisposable = SimpleDisposable()
				var sink: Signal<Int, TestError>.Observer!

				let producer = SignalProducer<Int, TestError>() { observer, disposable in
					disposable.addDisposable(addedDisposable)
					sink = observer
				}

				producer.startWithSignal { _ in }
				expect(addedDisposable.disposed).to(beFalsy())

				sendError(sink, .Default)
				expect(addedDisposable.disposed).to(beTruthy())
			}
		}

		describe("start") {
			it("should immediately begin sending events") {
				let producer = SignalProducer<Int, NoError>(values: [1, 2])

				var values: [Int] = []
				var completed = false
				producer.start(next: {
					values.append($0)
				}, completed: {
					completed = true
				})

				expect(values).to(equal([1, 2]))
				expect(completed).to(beTruthy())
			}

			it("should send interrupted if disposed") {
				let producer = SignalProducer<(), NoError>.never

				var interrupted = false
				let disposable = producer.start(interrupted: {
					interrupted = true
				})

				expect(interrupted).to(beFalsy())

				disposable.dispose()
				expect(interrupted).to(beTruthy())
			}

			it("should release sink when disposed") {
				weak var objectRetainedByObserver: NSObject?
				var disposable: Disposable!
				let test: () -> () = {
					let producer = SignalProducer<Int, NoError>.never
					let object = NSObject()
					objectRetainedByObserver = object
					disposable = producer.start { _ in object }
				}

				test()
				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			describe("trailing closure") {
				it("receives next values") {
					var values = [Int]()
					let (producer, sink) = SignalProducer<Int, NoError>.buffer()

					producer.start(next: { next in
						values.append(next)
					})

					sendNext(sink, 1)
					sendNext(sink, 2)
					sendNext(sink, 3)

					sendCompleted(sink)

					expect(values).to(equal([1, 2, 3]))
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
					expect(counter).to(equal(0))

					producer.start()
					expect(counter).to(equal(1))

					producer.start()
					expect(counter).to(equal(2))
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, NoError>(values: [1, 2, 3, 4])

					let producer = baseProducer.lift { signal in
						return signal.map { $0 * $0 }
					}
					let result = producer.collect().single()

					expect(result?.value).to(equal([1, 4, 9, 16]))
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
					expect(counter).to(equal(0))

					producer.start()
					expect(counter).to(equal(1))

					producer.start()
					expect(counter).to(equal(2))
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

					expect(result?.value).to(equal([5, 7, 9]))
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
				
				expect(result?.value).to(equal([[1, 4], [2, 4]]))
			}
			
			it("should zip the events to one array") {
				let producer = zip([producerA, producerB])
				let result = producer.collect().single()
				
				expect(result?.value).to(equal([[1, 3], [2, 4]]))
			}
		}

		describe("timer") {
			it("should send the current date at the given interval") {
				let scheduler = TestScheduler()
				let producer = timer(1, onScheduler: scheduler, withLeeway: 0)

				var dates: [NSDate] = []
				producer.start(next: { dates.append($0) })

				scheduler.advanceByInterval(0.9)
				expect(dates).to(equal([]))

				scheduler.advanceByInterval(1)
				let firstTick = scheduler.currentDate
				expect(dates).to(equal([firstTick]))

				scheduler.advance()
				expect(dates).to(equal([firstTick]))

				scheduler.advanceByInterval(0.2)
				let secondTick = scheduler.currentDate
				expect(dates).to(equal([firstTick, secondTick]))

				scheduler.advanceByInterval(1)
				expect(dates).to(equal([firstTick, secondTick, scheduler.currentDate]))
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
				let (baseProducer, sink) = SignalProducer<Int, TestError>.buffer()

				var started = 0
				var event = 0
				var next = 0
				var completed = 0
				var terminated = 0

				let producer = baseProducer
					.on(started: { () -> () in
						started += 1
					}, event: { (e: Event<Int, TestError>) -> () in
						event += 1
					}, next: { (n: Int) -> () in
						next += 1
					}, completed: { () -> () in
						completed += 1
					}, terminated: { () -> () in
						terminated += 1
					})

				producer.start()
				expect(started).to(equal(1))

				producer.start()
				expect(started).to(equal(2))

				sendNext(sink, 1)
				expect(event).to(equal(2))
				expect(next).to(equal(2))

				sendCompleted(sink)
				expect(event).to(equal(4))
				expect(completed).to(equal(2))
				expect(terminated).to(equal(2))
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
				expect(invoked).to(beFalsy())

				scheduler.advance()
				expect(invoked).to(beTruthy())
			}

			it("should forward events on their original scheduler") {
				let startScheduler = TestScheduler()
				let testScheduler = TestScheduler()

				let producer = timer(2, onScheduler: testScheduler, withLeeway: 0)

				var next: NSDate?
				producer.startOn(startScheduler).start(next: { next = $0 })

				startScheduler.advanceByInterval(2)
				expect(next).to(beNil())

				testScheduler.advanceByInterval(1)
				expect(next).to(beNil())

				testScheduler.advanceByInterval(1)
				expect(next).to(equal(testScheduler.currentDate))
			}
		}

		describe("flatMapError") {
			it("should invoke the handler and start new producer for an error") {
				let (baseProducer, baseSink) = SignalProducer<Int, TestError>.buffer()
				sendNext(baseSink, 1)
				sendError(baseSink, .Default)

				var values: [Int] = []
				var completed = false

				baseProducer
					.flatMapError { (error: TestError) -> SignalProducer<Int, TestError> in
						expect(error).to(equal(TestError.Default))
						expect(values).to(equal([1]))

						let (innerProducer, innerSink) = SignalProducer<Int, TestError>.buffer()
						sendNext(innerSink, 2)
						sendCompleted(innerSink)
						return innerProducer
					}
					.start(next: {
						values.append($0)
					}, completed: {
						completed = true
					})

				expect(values).to(equal([1, 2]))
				expect(completed).to(beTruthy())
			}
		}

		describe("flatten") {
			describe("FlattenStrategy.Concat") {
				describe("sequencing") {
					var completePrevious: (Void -> Void)!
					var sendSubsequent: (Void -> Void)!
					var completeOuter: (Void -> Void)!

					var subsequentStarted = false

					beforeEach {
						let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, NoError>, NoError>.buffer()
						let (previousProducer, previousSink) = SignalProducer<Int, NoError>.buffer()

						subsequentStarted = false
						let subsequentProducer = SignalProducer<Int, NoError> { _ in
							subsequentStarted = true
						}

						completePrevious = { sendCompleted(previousSink) }
						sendSubsequent = { sendNext(outerSink, subsequentProducer) }
						completeOuter = { sendCompleted(outerSink) }

						outerProducer.flatten(.Concat).start()
						sendNext(outerSink, previousProducer)
					}

					it("should immediately start subsequent inner producer if previous inner producer has already completed") {
						completePrevious()
						sendSubsequent()
						expect(subsequentStarted).to(beTruthy())
					}

					context("with queued producers") {
						beforeEach {
							// Place the subsequent producer into `concat`'s queue.
							sendSubsequent()
							expect(subsequentStarted).to(beFalsy())
						}

						it("should start subsequent inner producer upon completion of previous inner producer") {
							completePrevious()
							expect(subsequentStarted).to(beTruthy())
						}

						it("should start subsequent inner producer upon completion of previous inner producer and completion of outer producer") {
							completeOuter()
							completePrevious()
							expect(subsequentStarted).to(beTruthy())
						}
					}
				}

				it("should forward an error from an inner producer") {
					let errorProducer = SignalProducer<Int, TestError>(error: TestError.Default)
					let outerProducer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: errorProducer)

					var error: TestError?
					(outerProducer.flatten(.Concat)).start(error: { e in
						error = e
					})

					expect(error).to(equal(TestError.Default))
				}

				it("should forward an error from the outer producer") {
					let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()

					var error: TestError?
					outerProducer.flatten(.Concat).start(error: { e in
						error = e
					})

					sendError(outerSink, TestError.Default)
					expect(error).to(equal(TestError.Default))
				}

				describe("completion") {
					var completeOuter: (Void -> Void)!
					var completeInner: (Void -> Void)!

					var completed = false

					beforeEach {
						let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, NoError>, NoError>.buffer()
						let (innerProducer, innerSink) = SignalProducer<Int, NoError>.buffer()

						completeOuter = { sendCompleted(outerSink) }
						completeInner = { sendCompleted(innerSink) }

						completed = false
						outerProducer.flatten(.Concat).start(completed: {
							completed = true
						})

						sendNext(outerSink, innerProducer)
					}

					it("should complete when inner producers complete, then outer producer completes") {
						completeInner()
						expect(completed).to(beFalsy())

						completeOuter()
						expect(completed).to(beTruthy())
					}

					it("should complete when outer producers completes, then inner producers complete") {
						completeOuter()
						expect(completed).to(beFalsy())

						completeInner()
						expect(completed).to(beTruthy())
					}
				}
			}

			describe("FlattenStrategy.Merge") {
				describe("behavior") {
					var completeA: (Void -> Void)!
					var sendA: (Void -> Void)!
					var completeB: (Void -> Void)!
					var sendB: (Void -> Void)!

					var outerCompleted = false

					var recv = [Int]()

					beforeEach {
						let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, NoError>, NoError>.buffer()
						let (producerA, sinkA) = SignalProducer<Int, NoError>.buffer()
						let (producerB, sinkB) = SignalProducer<Int, NoError>.buffer()

						completeA = { sendCompleted(sinkA) }
						completeB = { sendCompleted(sinkB) }

						var a = 0
						sendA = { sendNext(sinkA, a++) }

						var b = 100
						sendB = { sendNext(sinkB, b++) }

						sendNext(outerSink, producerA)
						sendNext(outerSink, producerB)

						outerProducer.flatten(.Merge).start(next: { i in
							recv.append(i)
						}, error: { _ in () }, completed: {
							outerCompleted = true
						})

						sendCompleted(outerSink)
					}

					it("should forward values from any inner signals") {
						sendA()
						sendA()
						sendB()
						sendA()
						sendB()
						expect(recv).to(equal([0, 1, 100, 2, 101]))
					}

					it("should complete when all signals have completed") {
						completeA()
						expect(outerCompleted).to(beFalsy())
						completeB()
						expect(outerCompleted).to(beTruthy())
					}
				}

				describe("error handling") {
					it("should forward an error from an inner signal") {
						let errorProducer = SignalProducer<Int, TestError>(error: TestError.Default)
						let outerProducer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: errorProducer)

						var error: TestError?
						outerProducer.flatten(.Merge).start(error: { e in
							error = e
						})
						expect(error).to(equal(TestError.Default))
					}

					it("should forward an error from the outer signal") {
						let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()

						var error: TestError?
						outerProducer.flatten(.Merge).start(error: { e in
							error = e
						})

						sendError(outerSink, TestError.Default)
						expect(error).to(equal(TestError.Default))
					}
				}
			}

			describe("FlattenStrategy.Latest") {
				it("should forward values from the latest inner signal") {
					let (outer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()
					let (firstInner, firstInnerSink) = SignalProducer<Int, TestError>.buffer()
					let (secondInner, secondInnerSink) = SignalProducer<Int, TestError>.buffer()

					var receivedValues: [Int] = []
					var errored = false
					var completed = false

					outer.flatten(.Latest).start(
						next: {
							receivedValues.append($0)
						},
						error: { _ in
							errored = true
						},
						completed: {
							completed = true
					})

					sendNext(firstInnerSink, 1)
					sendNext(secondInnerSink, 2)
					sendNext(outerSink, SignalProducer(value: 0))
					sendNext(outerSink, firstInner)
					sendNext(outerSink, secondInner)
					sendCompleted(outerSink)

					expect(receivedValues).to(equal([ 0, 1, 2 ]))
					expect(errored).to(beFalsy())
					expect(completed).to(beFalsy())

					sendNext(firstInnerSink, 3)
					sendCompleted(firstInnerSink)
					sendNext(secondInnerSink, 4)
					sendCompleted(secondInnerSink)

					expect(receivedValues).to(equal([ 0, 1, 2, 4 ]))
					expect(errored).to(beFalsy())
					expect(completed).to(beTruthy())
				}

				it("should forward an error from an inner signal") {
					let inner = SignalProducer<Int, TestError>(error: .Default)
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					let result = outer.flatten(.Latest).first()
					expect(result?.error).to(equal(TestError.Default))
				}

				it("should forward an error from the outer signal") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(error: .Default)

					let result = outer.flatten(.Latest).first()
					expect(result?.error).to(equal(TestError.Default))
				}

				it("should complete when the original and latest signals have completed") {
					let inner = SignalProducer<Int, TestError>.empty
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.Latest).start(completed: {
						completed = true
					})

					expect(completed).to(beTruthy())
				}

				it("should complete when the outer signal completes before sending any signals") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>.empty

					var completed = false
					outer.flatten(.Latest).start(completed: {
						completed = true
					})

					expect(completed).to(beTruthy())
				}

				it("should not deadlock") {
					let producer = SignalProducer<Int, NoError>(value: 1)
						.flatMap(.Latest) { _ in SignalProducer(value: 10) }

					let result = producer.take(1).last()
					expect(result?.value).to(equal(10))
				}
			}

			describe("interruption") {
				var innerSink: Signal<(), NoError>.Observer!
				var outerSink: Signal<SignalProducer<(), NoError>, NoError>.Observer!
				var execute: (FlattenStrategy -> Void)!

				var interrupted = false
				var completed = false

				beforeEach {
					let (innerProducer, innerObserver) = SignalProducer<(), NoError>.buffer()
					let (outerProducer, outerObserver) = SignalProducer<SignalProducer<(), NoError>, NoError>.buffer()

					innerSink = innerObserver
					outerSink = outerObserver

					execute = { strategy in
						interrupted = false
						completed = false

						outerProducer
							.flatten(strategy)
							.start(interrupted: { _ in
								interrupted = true
							}, completed: { _ in
								completed = true
							})
					}

					sendNext(outerSink, innerProducer)
				}

				describe("Concat") {
					it("should drop interrupted from an inner producer") {
						execute(.Concat)

						sendInterrupted(innerSink)
						expect(interrupted).to(beFalsy())
						expect(completed).to(beFalsy())

						sendCompleted(outerSink)
						expect(completed).to(beTruthy())
					}

					it("should forward interrupted from the outer producer") {
						execute(.Concat)
						sendInterrupted(outerSink)
						expect(interrupted).to(beTruthy())
					}
				}

				describe("Latest") {
					it("should drop interrupted from an inner producer") {
						execute(.Latest)

						sendInterrupted(innerSink)
						expect(interrupted).to(beFalsy())
						expect(completed).to(beFalsy())

						sendCompleted(outerSink)
						expect(completed).to(beTruthy())
					}

					it("should forward interrupted from the outer producer") {
						execute(.Latest)
						sendInterrupted(outerSink)
						expect(interrupted).to(beTruthy())
					}
				}

				describe("Merge") {
					it("should drop interrupted from an inner producer") {
						execute(.Merge)

						sendInterrupted(innerSink)
						expect(interrupted).to(beFalsy())
						expect(completed).to(beFalsy())

						sendCompleted(outerSink)
						expect(completed).to(beTruthy())
					}

					it("should forward interrupted from the outer producer") {
						execute(.Merge)
						sendInterrupted(outerSink)
						expect(interrupted).to(beTruthy())
					}
				}
			}
		}

		describe("times") {
			it("should start a signal N times upon completion") {
				let original = SignalProducer<Int, NoError>(values: [ 1, 2, 3 ])
				let producer = original.times(3)

				let result = producer.collect().single()
				expect(result?.value).to(equal([ 1, 2, 3, 1, 2, 3, 1, 2, 3 ]))
			}

			it("should produce an equivalent signal producer if count is 1") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original.times(1)

				let result = producer.collect().single()
				expect(result?.value).to(equal([ 1 ]))
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
					.Error(.Default)
				]

				// TODO: if let result = result where result.count == expectedEvents.count
				if result?.count != expectedEvents.count {
					fail("Invalid result: \(result)")
				} else {
					// Can't test for equality because Array<T> is not Equatable,
					// and neither is Event<T, E>.
					expect(result![0] == expectedEvents[0]).to(beTruthy())
					expect(result![1] == expectedEvents[1]).to(beTruthy())
					expect(result![2] == expectedEvents[2]).to(beTruthy())
				}
			}

			it("should evaluate lazily") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original.times(Int.max)

				let result = producer.take(1).single()
				expect(result?.value).to(equal(1))
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

				expect(result?.value).to(equal(1))
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

				expect(result?.error).to(equal(TestError.Error2))
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
				expect(result?.value).to(equal(1))
			}
		}

		describe("then") {
			it("should start the subsequent producer after the completion of the original") {
				let (original, sink) = SignalProducer<Int, NoError>.buffer()

				var subsequentStarted = false
				let subsequent = SignalProducer<Int, NoError> { observer, _ in
					subsequentStarted = true
				}

				let producer = original.then(subsequent)
				producer.start()
				expect(subsequentStarted).to(beFalsy())

				sendCompleted(sink)
				expect(subsequentStarted).to(beTruthy())
			}

			it("should forward errors from the original producer") {
				let original = SignalProducer<Int, TestError>(error: .Default)
				let subsequent = SignalProducer<Int, TestError>.empty

				let result = original.then(subsequent).first()
				expect(result?.error).to(equal(TestError.Default))
			}

			it("should forward errors from the subsequent producer") {
				let original = SignalProducer<Int, TestError>.empty
				let subsequent = SignalProducer<Int, TestError>(error: .Default)

				let result = original.then(subsequent).first()
				expect(result?.error).to(equal(TestError.Default))
			}

			it("should complete when both inputs have completed") {
				let (original, originalSink) = SignalProducer<Int, NoError>.buffer()
				let (subsequent, subsequentSink) = SignalProducer<String, NoError>.buffer()

				let producer = original.then(subsequent)

				var completed = false
				producer.start(completed: {
					completed = true
				})

				sendCompleted(originalSink)
				expect(completed).to(beFalsy())

				sendCompleted(subsequentSink)
				expect(completed).to(beTruthy())
			}
		}

		describe("first") {
			it("should start a signal then block on the first value") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.first()
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).to(equal(1))
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty.first()
				expect(result).to(beNil())
			}

			it("should return the first value if more than one value is sent") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]).first()
				expect(result?.value).to(equal(1))
			}

			it("should return an error if one occurs before the first value") {
				let result = SignalProducer<Int, TestError>(error: .Default).first()
				expect(result?.error).to(equal(TestError.Default))
			}
		}

		describe("single") {
			it("should start a signal then block until completion") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.single()
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				expect(result).to(beNil())

				sendCompleted(sink)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).to(equal(1))
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
				expect(result?.error).to(equal(TestError.Default))
			}
		}

		describe("last") {
			it("should start a signal then block until completion") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.last()
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				sendNext(sink, 2)
				expect(result).to(beNil())

				sendCompleted(sink)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).to(equal(2))
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty.last()
				expect(result).to(beNil())
			}

			it("should return the last value if more than one value is sent") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]).last()
				expect(result?.value).to(equal(2))
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default).last()
				expect(result?.error).to(equal(TestError.Default))
			}
		}

		describe("wait") {
			it("should start a signal then block until completion") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<(), NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer.wait()
				}
				expect(result).to(beNil())

				sendCompleted(sink)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).toNot(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default).wait()
				expect(result.error).to(equal(TestError.Default))
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
				
				expect(upstreamDisposable.disposed).to(beFalsy())
				
				downstreamDisposable.dispose()
				expect(upstreamDisposable.disposed).to(beTruthy())
			}
		}
	}
}

extension SignalProducer {
	/// Creates a producer that can be started as many times as elements in `results`.
	/// Each signal will immediately send either a value or an error.
	private static func attemptWithResults<C: CollectionType where C.Generator.Element == Result<T, E>, C.Index.Distance == Int>(results: C) -> SignalProducer<T, E> {
		let resultCount = results.count
		var operationIndex = 0

		precondition(resultCount > 0)

		let operation: () -> Result<T, E> = {
			if operationIndex < resultCount {
				return results[results.startIndex.advancedBy(operationIndex++)]
			} else {
				fail("Operation started too many times")

				return results[results.startIndex.advancedBy(0)]
			}
		}

		return SignalProducer.attempt(operation)
	}
}
