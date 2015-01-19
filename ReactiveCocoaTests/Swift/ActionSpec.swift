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
		describe("Action") {
			var action: Action<Int, String>!
			var enabled: MutableProperty<Bool>!

			var executionCount = 0
			var values: [String] = []
			var errors: [NSError] = []

			var scheduler: TestScheduler!
			let testError = RACError.Empty.error

			beforeEach {
				executionCount = 0
				values = []
				errors = []
				enabled = MutableProperty(false)

				scheduler = TestScheduler()
				action = Action(enabledIf: enabled) { number in
					return SignalProducer { observer, disposable in
						executionCount++

						if number % 2 == 0 {
							sendNext(observer, "\(number)")
							sendNext(observer, "\(number)\(number)")

							scheduler.schedule {
								sendCompleted(observer)
							}
						} else {
							scheduler.schedule {
								sendError(observer, testError)
							}
						}
					}
				}

				action.values.observe { values.append($0) }
				action.errors.observe { errors.append($0) }
			}

			it("should be disabled and not executing after initialization") {
				expect(action.enabled.value).to(beFalsy())
				expect(action.executing.value).to(beFalsy())
			}

			it("should error if executed while disabled") {
				var receivedError: NSError?
				action.apply(0).start(error: {
					receivedError = $0
				})

				expect(receivedError).to(equal(RACError.ActionNotEnabled.error))
			}

			it("should enable and disable based on the given property") {
				enabled.value = true
				expect(action.enabled.value).to(beTruthy())
				expect(action.executing.value).to(beFalsy())

				enabled.value = false
				expect(action.enabled.value).to(beFalsy())
				expect(action.executing.value).to(beFalsy())
			}

			describe("execution") {
				beforeEach {
					enabled.value = true
				}

				it("should execute successfully") {
					var receivedValue: String?

					action.apply(0).start(next: {
						receivedValue = $0
					})

					expect(executionCount).to(equal(1))
					expect(action.executing.value).to(beTruthy())
					expect(action.enabled.value).to(beFalsy())

					expect(receivedValue).to(equal("00"))
					expect(values).to(equal([ "0", "00" ]))
					expect(errors).to(equal([]))

					scheduler.run()
					expect(action.executing.value).to(beFalsy())
					expect(action.enabled.value).to(beTruthy())

					expect(values).to(equal([ "0", "00" ]))
					expect(errors).to(equal([]))
				}

				it("should execute with an error") {
					var receivedError: NSError?

					action.apply(1).start(error: {
						receivedError = $0
					})

					expect(executionCount).to(equal(1))
					expect(action.executing.value).to(beTruthy())
					expect(action.enabled.value).to(beFalsy())

					scheduler.run()
					expect(action.executing.value).to(beFalsy())
					expect(action.enabled.value).to(beTruthy())

					expect(values).to(equal([]))
					expect(errors).to(equal([ testError ]))
				}
			}
		}
	}
}
