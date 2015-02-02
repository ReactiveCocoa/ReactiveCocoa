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
			context("sequencing") {
				var outerSink: Signal<SignalProducer<Int, NoError>, NoError>.Observer!
				var outerProducer: SignalProducer<SignalProducer<Int, NoError>, NoError>!

				var previousSink: Signal<Int, NoError>.Observer!
				var previousProducer: SignalProducer<Int, NoError>!

				var subsequentSink: Signal<Int, NoError>.Observer!
				var subsequentProducer: SignalProducer<Int, NoError>!
				var subsequentStarted = false

				beforeEach {
					outerProducer = SignalProducer { observer, _ in
						outerSink = observer
					}

					previousProducer = SignalProducer { observer, _ in
						previousSink = observer
					}

					subsequentStarted = false
					subsequentProducer = SignalProducer<Int, NoError> { observer, _ in
						subsequentStarted = true
					}

					concat(outerProducer).start()
					sendNext(outerSink, previousProducer)
				}

				it("should immediately start subsequent inner producers if previous inner producer has already completed") {
					sendCompleted(previousSink)
					sendNext(outerSink, subsequentProducer)
					expect(subsequentStarted).to(beTrue())
				}

				context("with queued producers") {
					beforeEach {
						// Place the subsequent producer into `concat`'s queue.
						sendNext(outerSink, subsequentProducer)
						expect(subsequentStarted).to(beFalse())
					}

					it("should start subsequent inner producer upon completion of previous inner producer") {
						sendCompleted(previousSink)
						expect(subsequentStarted).to(beTrue())
					}

					it("should start subsequent inner producer upon completion of previous inner producer and completion of outer producer") {
						sendCompleted(outerSink)
						sendCompleted(previousSink)
						expect(subsequentStarted).to(beTrue())
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
				var sink: Signal<SignalProducer<Int, TestError>, TestError>.Observer!
				let outerProducer = SignalProducer { observer, _ in
					sink = observer
				}

				var error: TestError?
				concat(outerProducer).start(error: { e in
					error = e
				})

				sendError(sink, TestError.Default)
				expect(error).to(equal(TestError.Default))
			}

			context("completion") {
				var outerSink: Signal<SignalProducer<Int, NoError>, NoError>.Observer!
				var outerProducer: SignalProducer<SignalProducer<Int, NoError>, NoError>!

				var innerSink: Signal<Int, NoError>.Observer!
				var innerProducer: SignalProducer<Int, NoError>!

				var completed = false

				beforeEach {
					outerProducer = SignalProducer { observer, _ in
						outerSink = observer
					}
					innerProducer = SignalProducer { observer, _ in
						innerSink = observer
					}

					completed = false
					concat(outerProducer).start(completed: {
						completed = true
					})
					sendNext(outerSink, innerProducer)
				}

				it("should complete when inner producers complete, then outer producer completes") {
					sendCompleted(innerSink)
					expect(completed).to(beFalse())

					sendCompleted(outerSink)
					expect(completed).to(beTrue())
				}

				it("should complete when outer producers completes, then inner producers complete") {
					sendCompleted(outerSink)
					expect(completed).to(beFalse())

					sendCompleted(innerSink)
					expect(completed).to(beTrue())
				}
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
