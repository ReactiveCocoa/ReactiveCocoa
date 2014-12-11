//
//  ColdSignalSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-12-07.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class ColdSignalSpec: QuickSpec {
	override func spec() {
		describe("startWithSink") {
			var subscribed = false
			let signal = ColdSignal<Int> { (sink, disposable) in
				subscribed = true

				sink.put(.Next(Box(0)))
				sink.put(.Completed)
			}

			beforeEach {
				subscribed = false
			}

			it("should wait to start until the closure has returned") {
				var receivedValue: Int?
				var receivedCompleted = false

				signal.startWithSink { disposable in
					expect(subscribed).to(beFalsy())

					return Event.sink(next: { value in
						receivedValue = value
					}, completed: {
						receivedCompleted = true
					})
				}

				expect(subscribed).to(beTruthy())
				expect(receivedValue).to(equal(0))
				expect(receivedCompleted).to(beTruthy())
			}

			it("should never attach the sink if disposed before returning") {
				var receivedValue: Int?
				var receivedCompleted = false

				signal.startWithSink { disposable in
					disposable.dispose()

					return Event.sink(next: { value in
						receivedValue = value
					}, completed: {
						receivedCompleted = true
					})
				}

				expect(subscribed).to(beFalsy())
				expect(receivedValue).to(beNil())
				expect(receivedCompleted).to(beFalsy())
			}

			it("should stop sending events to the sink when the returned disposable is disposed") {
				var receivedValue: Int?
				var receivedCompleted = false

				signal.startWithSink { disposable in
					return Event.sink(next: { value in
						receivedValue = value
						disposable.dispose()
					}, completed: {
						receivedCompleted = true
					})
				}

				expect(subscribed).to(beTruthy())
				expect(receivedValue).to(equal(0))
				expect(receivedCompleted).to(beFalsy())
			}
		}

		describe("lazy") {
			it("should execute the closure upon subscription") {
				var executionCount = 0
				let signal = ColdSignal<()>.lazy {
					executionCount++
					return ColdSignal.empty()
				}

				expect(executionCount).to(equal(0))

				signal.start()
				expect(executionCount).to(equal(1))

				signal.start()
				expect(executionCount).to(equal(2))
			}
		}

		describe("empty") {
			it("should return a signal that immediately completes") {
				var receivedOtherEvent = false
				var completed = false

				ColdSignal<()>.empty().start(next: { _ in
					receivedOtherEvent = true
				}, error: { _ in
					receivedOtherEvent = true
				}, completed: {
					completed = true
				})

				expect(completed).to(beTruthy())
				expect(receivedOtherEvent).to(beFalsy())
			}
		}

		describe("single") {
			it("should return a signal that sends the value then immediately completes") {
				var receivedOtherEvent = false
				var receivedValue: Int?
				var completed = false

				ColdSignal.single(0).start(next: { value in
					receivedValue = value
				}, error: { _ in
					receivedOtherEvent = true
				}, completed: {
					completed = true
				})

				expect(receivedValue).to(equal(0))
				expect(completed).to(beTruthy())
				expect(receivedOtherEvent).to(beFalsy())
			}
		}

		describe("error") {
			it("should return a signal that immediately errors") {
				var receivedOtherEvent = false
				var receivedError: NSError?

				let testError = RACError.Empty.error

				ColdSignal<()>.error(testError).start(next: { _ in
					receivedOtherEvent = true
				}, error: { error in
					receivedError = error
				}, completed: {
					receivedOtherEvent = true
				})

				expect(receivedError).to(equal(testError))
				expect(receivedOtherEvent).to(beFalsy())
			}
		}

		describe("never") {
			it("should return a signal never sends any events") {
				var receivedEvent = false

				ColdSignal<()>.never().startWithSink { disposable in
					return SinkOf { _ in receivedEvent = true }
				}

				expect(receivedEvent).to(beFalsy())
			}
		}

		describe("zipWith") {
			it("should combine pairs") {
				let firstSignal = ColdSignal.fromValues([ 1, 2, 3 ])
				let secondSignal = ColdSignal.fromValues([ "foo", "bar", "buzz", "fuzz" ])

				let result = firstSignal
					.zipWith(secondSignal)
					.map { num, str in "\(num)\(str)" }
					.reduce(initial: []) { $0 + [ $1 ] }
					.first()

				expect(result.value()).to(equal([ "1foo", "2bar", "3buzz" ]))
			}
		}
	}
}
