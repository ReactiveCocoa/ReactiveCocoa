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
			pending("should start subsequent inner signals upon completion") {
			}

			pending("should forward an error from an inner signal") {
			}

			pending("should forward an error from the outer signal") {
			}

			pending("should complete when all signals have completed") {
			}
		}

		describe("merge") {
			pending("should forward values from any inner signals") {
			}

			pending("should forward an error from an inner signal") {
			}

			pending("should forward an error from the outer signal") {
			}

			pending("should complete when all signals have completed") {
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
			pending("should start the subsequent signal after the completion of the original") {
			}

			pending("should forward errors from the original signal") {
			}

			pending("should forward errors from the subsequent signal") {
			}

			pending("should complete when both inputs have completed") {
			}
		}

		describe("first") {
			it("should start a signal then block on the first value") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()

				var result: Result<Int, NoError>?
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> first
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				expect(result?.value).toEventually(equal(1))
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
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> single
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				expect(result).to(beNil())

				sendCompleted(sink)
				expect(result?.value).toEventually(equal(1))
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
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> last
				}
				expect(result).to(beNil())

				sendNext(sink, 1)
				sendNext(sink, 2)
				expect(result).to(beNil())

				sendCompleted(sink)
				expect(result?.value).toEventually(equal(2))
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
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					result = producer |> wait
				}
				expect(result).to(beNil())

				sendCompleted(sink)
				expect(result?.value).toEventuallyNot(beNil())
			}
			
			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .Default) |> wait
				expect(result.error).to(equal(TestError.Default))
			}
		}
	}
}
