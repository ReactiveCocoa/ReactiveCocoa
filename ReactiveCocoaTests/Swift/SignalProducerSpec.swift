//
//  SignalProducerSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

import LlamaKit
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

			pending("should release signal observers when given disposable is disposed") {
			}

			pending("should dispose of added disposables upon completion") {
			}

			pending("should dispose of added disposables upon error") {
			}

			pending("should dispose of added disposables upon interruption") {
			}

			pending("should dispose of added disposables upon start() disposal") {
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
				let producerResult = success(producerValue) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				expect(signalProducer).to(sendValue(producerValue, sendError: nil, complete: true))
			}

			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let producerResult = failure(producerError) as Result<String, NSError>
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
			pending("should replay buffered events when started, then forward events as added") {
			}

			pending("should drop earliest events to maintain the capacity") {
			}
		}

		describe("SignalProducer.try") {
			it("should run the operation once per start()") {
				var operationRunTimes = 0
				let operation: () -> Result<String, NSError> = {
					operationRunTimes++

					return success("OperationValue")
				}

				SignalProducer.try(operation).start()
				SignalProducer.try(operation).start()

				expect(operationRunTimes).to(equal(2))
			}

			it("should send the value then complete") {
				let operationReturnValue = "OperationValue"
				let operation: () -> Result<String, NSError> = {
					return success(operationReturnValue)
				}

				let signalProducer = SignalProducer.try(operation)

				expect(signalProducer).to(sendValue(operationReturnValue, sendError: nil, complete: true))
			}

			it("should send the error") {
				let operationError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let operation: () -> Result<String, NSError> = {
					return failure(operationError)
				}

				let signalProducer = SignalProducer.try(operation)

				expect(signalProducer).to(sendValue(nil, sendError: operationError, complete: false))
			}
		}

		describe("startWithSignal") {
			pending("should invoke the closure before any effects or events") {
			}

			pending("should dispose of added disposables if disposed") {
			}

			pending("should send interrupted if disposed") {
			}

			pending("should release signal observers if disposed") {
			}

			pending("should not trigger effects if disposed before closure return") {
			}

			pending("should send interrupted if disposed before closure return") {
			}

			pending("should dispose of added disposables upon completion") {
			}

			pending("should dispose of added disposables upon error") {
			}
		}

		describe("start") {
			pending("should immediately begin sending events") {
			}

			pending("should send interrupted if disposed") {
			}

			pending("should release sink when disposed") {
			}
		}

		describe("lift") {
			describe("over unary operators") {
				pending("should invoke transformation once per started signal") {
				}

				pending("should not miss any events") {
				}
			}

			describe("over binary operators") {
				pending("should invoke transformation once per started signal") {
				}

				pending("should not miss any events") {
				}
			}
		}

		describe("timer") {
			pending("should send the current date at the given interval") {
			}

			pending("should release the signal when disposed") {
			}
		}

		describe("on") {
			pending("should attach event handlers to each started signal") {
			}
		}

		describe("startOn") {
			pending("should invoke effects on the given scheduler") {
			}

			pending("should forward events on their original scheduler") {
			}
		}

		describe("catch") {
			pending("should invoke the handler and start new producer for an error") {
			}
		}

		describe("join") {
			describe("JoinStrategy.Concat") {
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

						(outerProducer |> join(.Concat)).start()
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
					(outerProducer |> join(.Concat)).start(error: { e in
						error = e
					})

					expect(error).to(equal(TestError.Default))
				}

				it("should forward an error from the outer producer") {
					let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()

					var error: TestError?
					(outerProducer |> join(.Concat)).start(error: { e in
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
						(outerProducer |> join(.Concat)).start(completed: {
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

			describe("JoinStrategy.Merge") {
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

						(outerProducer |> join(.Merge)).start(next: { i in
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
						(outerProducer |> join(.Merge)).start(error: { e in
							error = e
						})
						expect(error).to(equal(TestError.Default))
					}

					it("should forward an error from the outer signal") {
						let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()

						var error: TestError?
						(outerProducer |> join(.Merge)).start(error: { e in
							error = e
						})

						sendError(outerSink, TestError.Default)
						expect(error).to(equal(TestError.Default))
					}
				}
			}

			describe("JoinStrategy.Latest") {
				it("should forward values from the latest inner signal") {
					let (outer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()
					let (firstInner, firstInnerSink) = SignalProducer<Int, TestError>.buffer()
					let (secondInner, secondInnerSink) = SignalProducer<Int, TestError>.buffer()

					var receivedValues: [Int] = []
					var errored = false
					var completed = false

					(outer |> join(.Latest)).start(
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
					let result = outer |> join(.Latest) |> first

					expect(result?.error).to(equal(TestError.Default))
				}

				it("should forward an error from the outer signal") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(error: .Default)
					let result = outer |> join(.Latest) |> first

					expect(result?.error).to(equal(TestError.Default))
				}

				it("should complete when the original and latest signals have completed") {
					let inner = SignalProducer<Int, TestError>.empty
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					(outer |> join(.Latest)).start(completed: {
						completed = true
					})

					expect(completed).to(beTruthy())
				}

				it("should complete when the outer signal completes before sending any signals") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>.empty

					var completed = false
					(outer |> join(.Latest)).start(completed: {
						completed = true
					})

					expect(completed).to(beTruthy())
				}
			}
		}

		describe("times") {
			it("should start a signal N times upon completion") {
				let original = SignalProducer<Int, NoError>(values: [ 1, 2, 3 ])
				let producer = original |> times(3)

				let result = producer |> collect |> single
				expect(result?.value).to(equal([ 1, 2, 3, 1, 2, 3, 1, 2, 3 ]))
			}

			it("should produce an equivalent signal producer if count is 1") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original |> times(1)

				let result = producer |> collect |> single
				expect(result?.value).to(equal([ 1 ]))
			}

			it("should produce an empty signal if count is 0") {
				let original = SignalProducer<Int, NoError>(value: 1)
				let producer = original |> times(0)

				let result = producer |> first
				expect(result).to(beNil())
			}

			it("should not repeat upon error") {
				let results: [Result<Int, TestError>] = [
					success(1),
					success(2),
					failure(.Default)
				]

				let original = SignalProducer.tryWithResults(results)
				let producer = original |> times(3)

				let events = producer
					|> materialize
					|> collect
					|> single
				let result = events?.value

				let expectedEvents: [Event<Int, TestError>] = [
					.Next(Box(1)),
					.Next(Box(2)),
					.Error(Box(.Default))
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
				let producer = original |> times(Int.max)

				let result = producer |> take(1) |> single
				expect(result?.value).to(equal(1))
			}
		}

		describe("retry") {
			it("should start a signal N times upon error") {
				let results: [Result<Int, TestError>] = [
					failure(.Error1),
					failure(.Error2),
					success(1)
				]

				let original = SignalProducer.tryWithResults(results)
				let producer = original |> retry(2)

				let result = producer |> single

				expect(result?.value).to(equal(1))
			}

			it("should forward errors that occur after all retries") {
				let results: [Result<Int, TestError>] = [
					failure(.Default),
					failure(.Error1),
					failure(.Error2),
				]

				let original = SignalProducer.tryWithResults(results)
				let producer = original |> retry(2)

				let result = producer |> single

				expect(result?.error).to(equal(TestError.Error2))
			}

			it("should not retry upon completion") {
				let results: [Result<Int, TestError>] = [
					success(1),
					success(2),
					success(3)
				]

				let original = SignalProducer.tryWithResults(results)
				let producer = original |> retry(2)

				let result = producer |> single
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

				let producer = original |> then(subsequent)
				producer.start()
				expect(subsequentStarted).to(beFalsy())

				sendCompleted(sink)
				expect(subsequentStarted).to(beTruthy())
			}

			it("should forward errors from the original producer") {
				let original = SignalProducer<Int, TestError>(error: .Default)
				let subsequent = SignalProducer<Int, TestError>.empty

				let result = original |> then(subsequent) |> first
				expect(result?.error).to(equal(TestError.Default))
			}

			it("should forward errors from the subsequent producer") {
				let original = SignalProducer<Int, TestError>.empty
				let subsequent = SignalProducer<Int, TestError>(error: .Default)

				let result = original |> then(subsequent) |> first
				expect(result?.error).to(equal(TestError.Default))
			}

			it("should complete when both inputs have completed") {
				let (original, originalSink) = SignalProducer<Int, NoError>.buffer()
				let (subsequent, subsequentSink) = SignalProducer<String, NoError>.buffer()

				let producer = original |> then(subsequent)

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
					result = producer |> first
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).to(equal(1))
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty |> first
				expect(result).to(beNil())
			}

			it("should return the first value if more than one value is sent") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]) |> first
				expect(result?.value).to(equal(1))
			}

			it("should return an error if one occurs before the first value") {
				let result = SignalProducer<Int, TestError>(error: .Default) |> first
				expect(result?.error).to(equal(TestError.Default))
			}
		}

		describe("single") {
			it("should start a signal then block until completion") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> single
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				expect(result).to(beNil())

				sendCompleted(sink)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).to(equal(1))
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, NoError>.empty |> single
				expect(result).to(beNil())
			}

			it("should return a nil result if more than one value is sent before completion") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]) |> single
				expect(result).to(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default) |> single
				expect(result?.error).to(equal(TestError.Default))
			}
		}

		describe("last") {
			it("should start a signal then block until completion") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<Int, NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> last
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
				let result = SignalProducer<Int, NoError>.empty |> last
				expect(result).to(beNil())
			}

			it("should return the last value if more than one value is sent") {
				let result = SignalProducer<Int, NoError>(values: [ 1, 2 ]) |> last
				expect(result?.value).to(equal(2))
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default) |> last
				expect(result?.error).to(equal(TestError.Default))
			}
		}

		describe("wait") {
			it("should start a signal then block until completion") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<(), NoError>?

				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> wait
				}
				expect(result).to(beNil())

				sendCompleted(sink)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
				expect(result?.value).toNot(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default) |> wait
				expect(result.error).to(equal(TestError.Default))
			}
		}
	}
}

extension SignalProducer {
	/// Creates a producer that can be started as many times as elements in `results`.
	/// Each signal will immediately send either a value or an error.
	private static func tryWithResults<C: CollectionType where C.Generator.Element == Result<T, E>, C.Index.Distance == Int>(results: C) -> SignalProducer<T, E> {
		let resultCount = countElements(results)
		var operationIndex = 0

		precondition(resultCount > 0)

		let operation: () -> Result<T, E> = {
			if operationIndex < resultCount {
				return results[advance(results.startIndex, operationIndex++)]
			} else {
				fail("Operation started too many times")

				return results[advance(results.startIndex, 0)]
			}
		}

		return SignalProducer.try(operation)
	}
}
