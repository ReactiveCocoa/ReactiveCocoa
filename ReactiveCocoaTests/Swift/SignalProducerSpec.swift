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
import Foundation

private func startSignalProducer<T: Equatable, E: Equatable>(signalProducer: SignalProducer<T, E>, #expectSentValue: T?, sentError expectSentError: E?, #complete: Bool) {
	startSignalProducer(signalProducer, expectSentValues: expectSentValue.map { [$0] } ?? [], sentError: expectSentError, complete: complete)
}

private func startSignalProducer<T: Equatable, E: Equatable>(signalProducer: SignalProducer<T, E>, expectSentValues: [T] = [], sentError expectSentError: E?, #complete: Bool) {
	var sentValues: [T] = []
	var sentError: E?
	var signalCompleted = false

	signalProducer.start(next: { value in
		sentValues.append(value)
	},
	error: { error in
		sentError = error
	},
	completed: {
		signalCompleted = true
	})

	expect(sentValues).to(equal(expectSentValues))

	if let error = expectSentError {
		expect(sentError).to(equal(expectSentError))
	}
	else {
		expect(sentError).to(beNil())
	}

	expect(signalCompleted).to(equal(complete))
}

class SignalProducerSpec: QuickSpec {
	override func spec() {
		describe("init") {
			it("should run the handler once per start()") {
				var handlerCalledTimes = 0
				let signalProducer = SignalProducer<String, NSError>({ observer, disposable in
					handlerCalledTimes++

					return
				})

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

			pending("should dispose of added disposables upon start() disposal") {
			}
		}

		describe("init(value:)") {
			it("should immediately send the value then complete") {
				let producerValue = "StringValue"
				let signalProducer = SignalProducer<String, NSError>(value: producerValue)

				startSignalProducer(signalProducer, expectSentValue: producerValue, sentError: nil, complete: true)
			}
		}

		describe("init(error:)") {
			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let signalProducer = SignalProducer<Int, NSError>(error: producerError)

				startSignalProducer(signalProducer, expectSentValue: nil, sentError: producerError, complete: false)
			}
		}

		describe("init(result:)") {
			it("should immediately send the value then complete") {
				let producerValue = "StringValue"
				let producerResult = success(producerValue) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				startSignalProducer(signalProducer, expectSentValue: producerValue, sentError: nil, complete: true)
			}

			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let producerResult = failure(producerError) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				startSignalProducer(signalProducer, expectSentValue: nil, sentError: producerError, complete: false)
			}
		}

		describe("init(values:)") {
			it("should immediately send the sequence of values") {
				let sequenceValues = [1, 2, 3]
				let signalProducer = SignalProducer<Int, NSError>(values: sequenceValues)

				startSignalProducer(signalProducer, expectSentValues: sequenceValues, sentError: nil, complete: false)
			}
		}

		describe("SignalProducer.empty") {
			it("should immediately complete") {
				let signalProducer = SignalProducer<Int, NSError>.empty

				startSignalProducer(signalProducer, expectSentValue: nil, sentError: nil, complete: true)
			}
		}

		describe("SignalProducer.never") {
			it("should not send any events") {
				let signalProducer = SignalProducer<Int, NSError>.never

				startSignalProducer(signalProducer, expectSentValue: nil, sentError: nil, complete: false)
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

				startSignalProducer(signalProducer, expectSentValue: operationReturnValue, sentError: nil, complete: true)
			}

			it("should send the error") {
				let operationError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let operation: () -> Result<String, NSError> = {
					return failure(operationError)
				}

				let signalProducer = SignalProducer.try(operation)

				startSignalProducer(signalProducer, expectSentValue: nil, sentError: operationError, complete: false)
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
			pending("should start a signal then block on the first value") {
			}

			pending("should return a nil result if no values are sent before completion") {
			}

			pending("should return an error if one occurs before the first value") {
			}
		}

		describe("single") {
			pending("should start a signal then block until completion") {
			}

			pending("should return a nil result if no values are sent before completion") {
			}

			pending("should return a nil result if too many values are sent before completion") {
			}

			pending("should return an error if one occurs") {
			}
		}

		describe("last") {
			pending("should start a signal then block until completion") {
			}

			pending("should return a nil result if no values are sent before completion") {
			}

			pending("should return an error if one occurs") {
			}
		}

		describe("wait") {
			pending("should start a signal then block until completion") {
			}
			
			pending("should return an error if one occurs") {
			}
		}
	}
}
