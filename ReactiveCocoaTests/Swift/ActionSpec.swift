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

		var scheduler: TestScheduler!
		var enabledSink: SinkOf<Bool>!

		let testError = RACError.Empty.error

		beforeEach {
			let (signal, sink) = HotSignal<Bool>.pipe()
			enabledSink = sink

			scheduler = TestScheduler()
			action = Action(enabledIf: signal, serializedOnScheduler: scheduler) { number in
				return ColdSignal { (sink, disposable) in
					if number % 2 == 0 {
						sink.put(.Next(Box("\(number)")))
						sink.put(.Next(Box("\(number)\(number)")))
						sink.put(.Completed)
					} else {
						sink.put(.Error(testError))
					}
				}
			}
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
	}
}
