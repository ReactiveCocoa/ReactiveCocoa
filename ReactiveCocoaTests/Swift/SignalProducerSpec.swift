//
//  SignalProducerSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class SignalProducerSpec: QuickSpec {
	override func spec() {
		describe("init") {
			pending("should run the handler once per start()") {
			}

			pending("should release signal observers when given disposable is disposed") {
			}

			pending("should dispose of added disposables upon completion") {
			}

			pending("should dispose of added disposables upon error") {
			}

			pending("should dispose of added disposables upon start() disposal") {
			}
		}

		describe("init(value:)") {
			pending("should immediately send the value then complete") {
			}
		}

		describe("init(error:)") {
			pending("should immediately send the error") {
			}
		}

		describe("init(result:)") {
			pending("should immediately send the value then complete") {
			}

			pending("should immediately send the error") {
			}
		}

		describe("init(values:)") {
			pending("should immediately send the sequence of values") {
			}
		}

		describe("SignalProducer.empty") {
			pending("should immediately complete") {
			}
		}

		describe("SignalProducer.never") {
			pending("should not send any events") {
			}
		}

		describe("SignalProducer.buffer") {
			pending("should replay buffered events when started, then forward events as added") {
			}

			pending("should drop earliest events to maintain the capacity") {
			}
		}

		describe("SignalProducer.try") {
			pending("should run the operation once per start()") {
			}

			pending("should send the value then complete") {
			}

			pending("should send the error") {
			}
		}

		describe("startWithSignal") {
			pending("should invoke the closure before any effects or events") {
			}

			pending("should interrupt effects and stop sending events if disposed") {
			}

			pending("should release signal observers if disposed") {
			}

			pending("should not trigger effects if disposed before closure return") {
			}

			pending("should dispose of added disposables upon completion") {
			}

			pending("should dispose of added disposables upon error") {
			}
		}

		describe("start") {
			pending("should immediately begin sending events") {
			}

			pending("should interrupt effects and stop sending events if disposed") {
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

		describe("concat") {
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

					concat(outerProducer).start()
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
				concat(outerProducer).start(error: { e in
					error = e
				})
				expect(error).to(equal(TestError.Default))
			}

			it("should forward an error from the outer producer") {
				let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()

				var error: TestError?
				concat(outerProducer).start(error: { e in
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
					concat(outerProducer).start(completed: {
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

		describe("merge") {
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
					
					merge(outerProducer).start(next: { i in
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
					merge(outerProducer).start(error: { e in
						error = e
					})
					expect(error).to(equal(TestError.Default))
				}
				
				it("should forward an error from the outer signal") {
					let (outerProducer, outerSink) = SignalProducer<SignalProducer<Int, TestError>, TestError>.buffer()
					
					var error: TestError?
					merge(outerProducer).start(error: { e in
						error = e
					})
					
					sendError(outerSink, TestError.Default)
					expect(error).to(equal(TestError.Default))
				}
			}
		}

		describe("switchToLatest") {
			pending("should forward values from the latest inner signal") {
			}

			pending("should forward an error from an inner signal") {
			}

			pending("should forward an error from the outer signal") {
			}

			pending("should complete when the original and latest signals have completed") {
			}
		}

		describe("repeat") {
			pending("should start a signal N times upon completion") {
			}

			pending("should not repeat upon error") {
			}
		}

		describe("retry") {
			pending("should start a signal N times upon error") {
			}

			pending("should forward errors that occur after all retries") {
			}

			pending("should not retry upon completion") {
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
