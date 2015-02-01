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
			it("should start the subsequent producer after the completion of the original") {
				var sink: Signal<Int, NoError>.Observer!
				let original = SignalProducer<Int, NoError> { observer, _ in
					sink = observer
				}

				var subsequentStarted = false
				let subsequent = SignalProducer<Int, NoError> { observer, _ in
					subsequentStarted = true
				}

				let producer = original |> then(subsequent)

				producer.start()
				expect(subsequentStarted).to(beFalse())
				sendCompleted(sink)
				expect(subsequentStarted).to(beTrue())
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
				var originalSink: Signal<Int, NoError>.Observer!
				let original = SignalProducer<Int, NoError> { observer, _ in
					originalSink = observer
				}
				var subsequentSink: Signal<String, NoError>.Observer!
				let subsequent = SignalProducer<String, NoError> { observer, _ in
					subsequentSink = observer
				}

				let producer = original |> then(subsequent)

				var completed = false
				producer.start(completed: {
					completed = true
				})

				sendCompleted(originalSink)
				expect(completed).to(beFalse())
				sendCompleted(subsequentSink)
				expect(completed).to(beTrue())
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
