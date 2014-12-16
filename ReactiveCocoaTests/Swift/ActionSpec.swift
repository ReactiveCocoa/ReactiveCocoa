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
			var enabledSink: SinkOf<Bool>!

			var executionCount = 0
			var values: [String] = []
			var errors: [NSError] = []

			var scheduler: TestScheduler!
			let testError = RACError.Empty.error

			beforeEach {
				executionCount = 0
				values = []
				errors = []

				let (signal, sink) = HotSignal<Bool>.pipe()
				enabledSink = sink

				scheduler = TestScheduler()
				action = Action(enabledIf: signal) { number in
					return ColdSignal { (sink, disposable) in
						executionCount++

						if number % 2 == 0 {
							sink.put(.Next(Box("\(number)")))
							sink.put(.Next(Box("\(number)\(number)")))

							scheduler.schedule {
								sink.put(.Completed)
							}
						} else {
							scheduler.schedule {
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
				action.apply(0).start(error: {
					receivedError = $0
				})

				expect(receivedError).to(equal(RACError.ActionNotEnabled.error))
			}

			it("should enable and disable based on the given signal") {
				enabledSink.put(true)
				expect(action.enabled.first().value()).to(beTruthy())
				expect(action.executing.first().value()).to(beFalsy())

				enabledSink.put(false)
				expect(action.enabled.first().value()).to(beFalsy())
				expect(action.executing.first().value()).to(beFalsy())
			}

			describe("execution") {
				beforeEach {
					enabledSink.put(true)
				}

				it("should execute successfully") {
					var receivedValue: String?

					action.apply(0).start(next: {
						receivedValue = $0
					})

					expect(executionCount).to(equal(1))
					expect(action.executing.first().value()).to(beTruthy())
					expect(action.enabled.first().value()).to(beFalsy())

					expect(receivedValue).to(equal("00"))
					expect(values).to(equal([ "0", "00" ]))
					expect(errors).to(equal([]))

					scheduler.run()
					expect(action.executing.first().value()).to(beFalsy())
					expect(action.enabled.first().value()).to(beTruthy())

					expect(values).to(equal([ "0", "00" ]))
					expect(errors).to(equal([]))
				}

				it("should execute with an error") {
					var receivedError: NSError?

					action.apply(1).start(error: {
						receivedError = $0
					})

					expect(executionCount).to(equal(1))
					expect(action.executing.first().value()).to(beTruthy())
					expect(action.enabled.first().value()).to(beFalsy())

					scheduler.run()
					expect(action.executing.first().value()).to(beFalsy())
					expect(action.enabled.first().value()).to(beTruthy())

					expect(values).to(equal([]))
					expect(errors).to(equal([ testError ]))
				}
			}
		}

		describe("CocoaAction") {
			var action: Action<()?, ()>!
			var cocoaAction: CocoaAction!

			beforeEach {
				action = Action { _ in .single(()) }

				cocoaAction = CocoaAction(action)
				expect(cocoaAction.enabled).toEventually(beTruthy())
			}

			#if os(OSX)
				it("should be compatible with AppKit") {
					let control = NSControl(frame: NSZeroRect)
					control.target = cocoaAction
					control.action = cocoaAction.selector
					control.performClick(nil)
				}
			#elseif os(iOS)
				it("should be compatible with UIKit") {
					let control = UIControl(frame: CGRectZero)
					control.addTarget(cocoaAction, action: cocoaAction.selector, forControlEvents: UIControlEvents.TouchDown)
					control.sendActionsForControlEvents(UIControlEvents.TouchDown)
				}
			#endif

			it("should generate KVO notifications for enabled") {
				var values: [Bool] = []

				cocoaAction
					.rac_valuesForKeyPath("enabled", observer: nil)
					.asColdSignal()
					.map { $0! as Bool }
					.start(next: { values.append($0) })

				expect(values).to(equal([ true ]))

				action.apply(nil).wait()
				expect(values).toEventually(equal([ true, false, true ]))
			}

			it("should generate KVO notifications for executing") {
				var values: [Bool] = []

				cocoaAction
					.rac_valuesForKeyPath("executing", observer: nil)
					.asColdSignal()
					.map { $0! as Bool }
					.start(next: { values.append($0) })

				expect(values).to(equal([ false ]))

				action.apply(nil).wait()
				expect(values).toEventually(equal([ false, true, false ]))
			}
		}
	}
}
