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

		describe("fromValues") {
			it("should return a signal that sends the values then complete") {
				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				let values = [ 0, 1, 2, 3 ]

				ColdSignal.fromValues(values).start(next: {
					receivedValues.append($0)
				}, error: { _ in
					errored = true
				}, completed: {
					completed = true
				})

				expect(receivedValues).to(equal(values))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}
		}

		describe("fromResult") {
			it("should return a signal that sends an error") {
				var receivedOtherEvent = false
				var receivedError: NSError?

				let testError = RACError.Empty.error
				let result: Result<()> = failure(testError)

				ColdSignal.fromResult(result).start(next: { _ in
					receivedOtherEvent = true
				}, error: { error in
					receivedError = error
				}, completed: {
					receivedOtherEvent = true
				})

				expect(receivedError).to(equal(testError))
				expect(receivedOtherEvent).to(beFalsy())
			}

			it("should return a signal that sends a value then completes") {
				var receivedOtherEvent = false
				var receivedValue: Int?
				var completed = false

				ColdSignal.fromResult(success(0)).start(next: { value in
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

		describe("mapAccumulate") {
			var disposed = false
			let baseSignal = ColdSignal<Int> { (sink, disposable) in
				for i in 0 ... 3 {
					if disposable.disposed {
						disposed = true
						return
					}

					sink.put(.Next(Box(i)))
				}

				sink.put(.Completed)
			}

			beforeEach {
				disposed = false
			}

			it("should thread a state through") {
				let newSignal: ColdSignal<Int> = baseSignal.mapAccumulate(initialState: 1) { (state, value) in
					return (state + 1, state * value)
				}

				var receivedValues: [Int] = []
				var completed = false
				var errored = false

				newSignal.start(next: {
					receivedValues.append($0)
				}, error: { _ in
					errored = true
				}, completed: {
					completed = true
				})

				expect(receivedValues).to(equal([ 0, 2, 6, 12 ]))
				expect(completed).to(beTruthy())
				expect(disposed).to(beFalsy())
				expect(errored).to(beFalsy())
			}

			it("should dispose of the underlying signal when a nil state is returned") {
				let newSignal: ColdSignal<Int> = baseSignal.mapAccumulate(initialState: 1) { (state, value) in
					let newState: Int? = (state > 2 ? nil : state + 1)
					return (newState, state * value)
				}

				var receivedValues: [Int] = []
				var completed = false
				var errored = false

				newSignal.start(next: {
					receivedValues.append($0)
				}, error: { _ in
					errored = true
				}, completed: {
					completed = true
				})

				expect(receivedValues).to(equal([ 0, 2, 6 ]))
				expect(completed).to(beTruthy())
				expect(disposed).to(beTruthy())
				expect(errored).to(beFalsy())
			}
		}

		describe("filter") {
			it("should omit values matching the predicate") {
				let result = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.filter { $0 % 2 == 0 }
					.reduce(initial: []) { $0 + [ $1 ] }
					.first()

				expect(result.value()).to(equal([ 0, 2, 4 ]))
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
