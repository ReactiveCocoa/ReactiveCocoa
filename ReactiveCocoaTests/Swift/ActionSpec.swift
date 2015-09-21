//
//  ActionSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-12-11.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

class ActionSpec: QuickSpec {
	override func spec() {
		describe("Action") {
			var action: Action<Int, String, NSError>!
			var enabled: MutableProperty<Bool>!

			var executionCount = 0
			var values: [String] = []
			var errors: [NSError] = []

			var scheduler: TestScheduler!
			let testError = NSError(domain: "ActionSpec", code: 1, userInfo: nil)

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

				action.values.observeNext { values.append($0) }
				action.errors.observeNext { errors.append($0) }
			}

			it("should be disabled and not executing after initialization") {
				expect(action.enabled.value).to(beFalsy())
				expect(action.executing.value).to(beFalsy())
			}

			it("should error if executed while disabled") {
				var receivedError: ActionError<NSError>?
				action.apply(0).startWithError {
					receivedError = $0
				}

				expect(receivedError).notTo(beNil())
				if let error = receivedError {
					let expectedError = ActionError<NSError>.NotEnabled
					expect(error == expectedError).to(beTruthy())
				}
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

					action.apply(0).startWithNext {
						receivedValue = $0
					}

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
					var receivedError: ActionError<NSError>?

					action.apply(1).startWithError {
						receivedError = $0
					}

					expect(executionCount).to(equal(1))
					expect(action.executing.value).to(beTruthy())
					expect(action.enabled.value).to(beFalsy())

					scheduler.run()
					expect(action.executing.value).to(beFalsy())
					expect(action.enabled.value).to(beTruthy())

					expect(receivedError).notTo(beNil())
					if let error = receivedError {
						let expectedError = ActionError<NSError>.ProducerError(testError)
						expect(error == expectedError).to(beTruthy())
					}

					expect(values).to(equal([]))
					expect(errors).to(equal([ testError ]))
				}
			}
		}

		describe("CocoaAction") {
			var action: Action<Int, Int, NoError>!

			beforeEach {
				action = Action { value in SignalProducer(value: value + 1) }
				expect(action.enabled.value).to(beTruthy())

				expect(action.unsafeCocoaAction.enabled).toEventually(beTruthy())
			}

			#if os(OSX)
				it("should be compatible with AppKit") {
					let control = NSControl(frame: NSZeroRect)
					control.target = action.unsafeCocoaAction
					control.action = CocoaAction.selector
					control.performClick(nil)
				}
			#elseif os(iOS)
				it("should be compatible with UIKit") {
					let control = UIControl(frame: CGRectZero)
					control.addTarget(action.unsafeCocoaAction, action: CocoaAction.selector, forControlEvents: UIControlEvents.TouchDown)
					control.sendActionsForControlEvents(UIControlEvents.TouchDown)
				}
			#endif

			it("should generate KVO notifications for enabled") {
				var values: [Bool] = []

				action.unsafeCocoaAction
					.rac_valuesForKeyPath("enabled", observer: nil)
					.toSignalProducer()
					.map { $0! as! Bool }
					.start(Event.sink(next: { values.append($0) }))

				expect(values).to(equal([ true ]))

				let result = action.apply(0).first()
				expect(result?.value).to(equal(1))
				expect(values).toEventually(equal([ true, false, true ]))
			}

			it("should generate KVO notifications for executing") {
				var values: [Bool] = []

				action.unsafeCocoaAction
					.rac_valuesForKeyPath("executing", observer: nil)
					.toSignalProducer()
					.map { $0! as! Bool }
					.start(Event.sink(next: { values.append($0) }))

				expect(values).to(equal([ false ]))

				let result = action.apply(0).first()
				expect(result?.value).to(equal(1))
				expect(values).toEventually(equal([ false, true, false ]))
			}
		}
	}
}
