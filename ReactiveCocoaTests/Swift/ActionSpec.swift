//
//  ActionSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-12-11.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class ActionSpec: QuickSpec {
	override func spec() {
		var action: Action<Int, String>!

		var executionCount = 0
		var values: [String] = []
		var errors: [NSError] = []

		var scheduler: TestScheduler!
		var enabledSink: SinkOf<Bool>!

		let testError = RACError.Empty.error

		beforeEach {
			executionCount = 0
			values = []
			errors = []

			let (signal, sink) = HotSignal<Bool>.pipe()
			enabledSink = sink

			scheduler = TestScheduler()
			action = Action(enabledIf: signal, serializedOnScheduler: scheduler) { number in
				return ColdSignal { (sink, disposable) in
					executionCount++

					if number % 2 == 0 {
						sink.put(.Next(Box("\(number)")))
						sink.put(.Next(Box("\(number)\(number)")))

						scheduler.scheduleAfter(1) {
							sink.put(.Completed)
						}
					} else {
						scheduler.scheduleAfter(1) {
							sink.put(.Error(testError))
						}
					}
				}
			}

			action.values.observe { values.append($0) }
			action.errors.observe { errors.append($0) }
		}

		it("should be disabled and not executing after initialization") {
			expect(action.enabled.first().value()).to(beFalsy())
			expect(action.executing.first().value()).to(beFalsy())
		}

		it("should error if executed while disabled") {
			var receivedError: NSError?
			action.execute(0).start(error: {
				receivedError = $0
			})

			expect(receivedError).to(beNil())

			scheduler.advance()
			expect(receivedError).to(equal(RACError.ActionNotEnabled.error))
		}

		it("should enable and disable based on the given signal") {
			enabledSink.put(true)
			expect(action.enabled.first().value()).to(beFalsy())

			scheduler.advance()
			expect(action.enabled.first().value()).to(beTruthy())
			expect(action.executing.first().value()).to(beFalsy())

			enabledSink.put(false)
			expect(action.enabled.first().value()).to(beTruthy())

			scheduler.advance()
			expect(action.enabled.first().value()).to(beFalsy())
			expect(action.executing.first().value()).to(beFalsy())
		}

		describe("execution") {
			beforeEach {
				enabledSink.put(true)

				scheduler.advance()
				expect(action.enabled.first().value()).to(beTruthy())
			}

			it("should execute successfully on the given scheduler") {
				var receivedValue: String?

				action.execute(0).start(next: {
					receivedValue = $0
				})

				expect(executionCount).to(equal(0))
				expect(action.executing.first().value()).to(beFalsy())

				scheduler.advanceByInterval(0.5)
				expect(executionCount).to(equal(1))
				expect(action.executing.first().value()).to(beTruthy())
				expect(action.enabled.first().value()).to(beFalsy())

				expect(receivedValue).to(equal("00"))
				expect(values).to(equal([ "0", "00" ]))
				expect(errors).to(equal([]))

				scheduler.run()
				expect(executionCount).to(equal(1))
				expect(action.executing.first().value()).to(beFalsy())
				expect(action.enabled.first().value()).to(beTruthy())

				expect(receivedValue).to(equal("00"))
				expect(values).to(equal([ "0", "00" ]))
				expect(errors).to(equal([]))
			}

			it("should execute with an error on the given scheduler") {
				var receivedError: NSError?

				action.execute(1).start(error: {
					receivedError = $0
				})

				expect(executionCount).to(equal(0))
				expect(action.executing.first().value()).to(beFalsy())

				scheduler.advanceByInterval(0.5)
				expect(executionCount).to(equal(1))
				expect(action.executing.first().value()).to(beTruthy())
				expect(action.enabled.first().value()).to(beFalsy())

				scheduler.run()
				expect(executionCount).to(equal(1))
				expect(action.executing.first().value()).to(beFalsy())
				expect(action.enabled.first().value()).to(beTruthy())

				expect(receivedError).to(equal(testError))
				expect(values).to(equal([]))
				expect(errors).to(equal([ testError ]))
			}
		}
	}
}
