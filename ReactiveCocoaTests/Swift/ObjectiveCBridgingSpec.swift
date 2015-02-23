//
//  ObjectiveCBridgingSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class ObjectiveCBridgingSpec: QuickSpec {
	override func spec() {
		describe("RACSignal.asSignalProducer") {
			it("should subscribe once per start()") {
				var subscriptions = 0

				let racSignal = RACSignal.createSignal { subscriber in
					subscriber.sendNext(subscriptions++)
					subscriber.sendCompleted()

					return nil
				}

				let producer = racSignal.asSignalProducer() |> map { $0 as Int }

				expect((producer |> single)?.value).to(equal(0))
				expect((producer |> single)?.value).to(equal(1))
				expect((producer |> single)?.value).to(equal(2))
			}

			it("should forward errors")	{
				let error = TestError.Default.nsError

				let racSignal = RACSignal.error(error)
				let producer = racSignal.asSignalProducer()
				let result = producer |> last

				expect(result?.error).to(equal(error))
			}
		}

		describe("asRACSignal") {
			describe("on a Signal") {
				it("should forward events") {
					let (signal, sink) = Signal<NSNumber, NoError>.pipe()
					let racSignal = asRACSignal(signal)

					var lastValue: NSNumber?
					var didComplete = false

					racSignal.subscribeNext({ number in
						lastValue = number as? NSNumber
					}, completed: {
						didComplete = true
					})

					expect(lastValue).to(beNil())

					for number in [1, 2, 3] {
						sendNext(sink, number)
						expect(lastValue).to(equal(number))
					}

					expect(didComplete).to(beFalse())
					sendCompleted(sink)
					expect(didComplete).to(beTrue())
				}

				it("should convert errors to NSError") {
					let (signal, sink) = Signal<AnyObject, TestError>.pipe()
					let racSignal = asRACSignal(signal)

					let expectedError = TestError.Error2
					var error: NSError?

					racSignal.subscribeError {
						error = $0
						return
					}

					sendError(sink, expectedError)

					expect(error?.domain).to(equal(TestError.domain))
					expect(error?.code).to(equal(expectedError.rawValue))
				}
			}

			describe("on a SignalProducer") {
				it("should start once per subscription") {
					var subscriptions = 0

					let producer = SignalProducer<NSNumber, NoError>.try {
						return success(subscriptions++)
					}
					let racSignal = asRACSignal(producer)

					expect(racSignal.first() as? NSNumber).to(equal(0))
					expect(racSignal.first() as? NSNumber).to(equal(1))
					expect(racSignal.first() as? NSNumber).to(equal(2))
				}

				it("should convert errors to NSError") {
					let producer = SignalProducer<AnyObject, TestError>(error: .Error1)
					let racSignal = asRACSignal(producer).materialize()

					let event = racSignal.first() as? RACEvent

					expect(event?.error.domain).to(equal(TestError.domain))
					expect(event?.error.code).to(equal(TestError.Error1.rawValue))
				}
			}
		}

		describe("RACCommand.asAction") {
			pending("should reflect the enabledness of the command") {
			}

			pending("should not execute the command upon apply()") {
			}

			pending("should execute the command once per start()") {
			}
		}

		describe("asRACCommand") {
			pending("should reflect the enabledness of the action") {
			}

			pending("should apply and start a signal once per execution") {
			}
		}
	}
}
