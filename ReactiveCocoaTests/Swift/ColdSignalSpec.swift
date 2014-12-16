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

extension ColdSignal {
	private func collect() -> [T]? {
		return reduce(initial: []) { $0 + [ $1 ] }
			.first()
			.value()
	}
}

class ColdSignalSpec: QuickSpec {
	override func spec() {
		describe("startWithSink") {
			var started = false
			let signal = ColdSignal<Int> { (sink, disposable) in
				started = true

				sink.put(.Next(Box(0)))
				sink.put(.Completed)
			}

			beforeEach {
				started = false
			}

			it("should wait to start until the closure has returned") {
				var receivedValue: Int?
				var receivedCompleted = false

				signal.startWithSink { disposable in
					expect(started).to(beFalsy())

					return Event.sink(next: { value in
						receivedValue = value
					}, completed: {
						receivedCompleted = true
					})
				}

				expect(started).to(beTruthy())
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

				expect(started).to(beFalsy())
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

				expect(started).to(beTruthy())
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

		describe("map") {
			it("should transform values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.map { $0 * 2 }
					.collect()

				expect(values).to(equal([ 0, 2, 4, 6, 8 ]))
			}
		}

		describe("filter") {
			it("should omit values matching the predicate") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.filter { $0 % 2 == 0 }
					.collect()

				expect(values).to(equal([ 0, 2, 4 ]))
			}
		}

		describe("scan") {
			it("should transform and aggregate values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.scan(initial: 0, +)
					.collect()

				expect(values).to(equal([ 0, 1, 3, 6, 10 ]))
			}
		}

		describe("reduce") {
			it("should aggregate values and send one upon completion") {
				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.reduce(initial: 0, +)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ 10 ]))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}
		}

		describe("combinePrevious") {
			it("should send tuples of current and previous") {
				let values = ColdSignal
					.fromValues([ 1, 2, 3 ])
					.combinePrevious(initial: 0)
					// Tuples don't distribute ==, so use an array.
					.map { a, b in [ a, b ] }
					.collect()

				expect(values).to(equal([
					[ 0, 1 ],
					[ 1, 2 ],
					[ 2, 3 ],
				]))
			}
		}

		describe("skip") {
			it("should skip no values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.skip(0)
					.collect()

				expect(values).to(equal([ 0, 1, 2, 3, 4 ]))
			}

			it("should skip multiple values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.skip(2)
					.collect()

				expect(values).to(equal([ 2, 3, 4 ]))
			}

			it("should skip more than the signal length") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.skip(10)
					.collect()

				expect(values).to(equal([]))
			}
		}

		describe("skipRepeats") {
			it("should skip equal elements") {
				let values = ColdSignal
					.fromValues([ 0, 0, 1, 2, 2, 3, 4, 4 ])
					.skipRepeats(identity)
					.collect()

				expect(values).to(equal([ 0, 1, 2, 3, 4 ]))
			}

			it("should skip elements matching a predicate") {
				let values = ColdSignal
					.fromValues([ 0, 0, 1, 2, 2, 3, 4, 4 ])
					.skipRepeats { a, b in
						return a * b == b
					}
					.collect()

				expect(values).to(equal([ 0, 2, 2, 3, 4, 4 ]))
			}
		}

		describe("skipWhile") {
			it("should skip until the predicate is false") {
				let values = ColdSignal
					.fromValues([ 0, 2, 1, 3, 4 ])
					.skipWhile { $0 % 2 == 0 }
					.collect()

				expect(values).to(equal([ 1, 3, 4 ]))
			}
		}

		describe("take") {
			it("should take no values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.take(0)
					.collect()

				expect(values).to(equal([]))
			}

			it("should take multiple values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.take(2)
					.collect()

				expect(values).to(equal([ 0, 1 ]))
			}

			it("should take more than the signal length") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.take(10)
					.collect()

				expect(values).to(equal([ 0, 1, 2, 3, 4 ]))
			}
		}

		describe("takeLast") {
			it("should take no values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.takeLast(0)
					.collect()

				expect(values).to(equal([]))
			}

			it("should take multiple values") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.takeLast(2)
					.collect()

				expect(values).to(equal([ 3, 4 ]))
			}

			it("should take more than the signal length") {
				let values = ColdSignal
					.fromValues([ 0, 1, 2, 3, 4 ])
					.takeLast(10)
					.collect()

				expect(values).to(equal([ 0, 1, 2, 3, 4 ]))
			}
		}

		describe("takeUntil") {
			it("should take values until the trigger fires") {
				let scheduler = TestScheduler()
				let signal = ColdSignal<Int> { (sink, disposable) in
					disposable.addDisposable(scheduler.scheduleAfter(1) {
						sink.put(.Next(Box(0)))
					})

					disposable.addDisposable(scheduler.scheduleAfter(2) {
						sink.put(.Next(Box(1)))
					})

					disposable.addDisposable(scheduler.scheduleAfter(3) {
						sink.put(.Next(Box(2)))
					})

					return
				}

				let (triggerSignal, triggerSink) = HotSignal<()>.pipe()
				let newSignal = signal.takeUntil(triggerSignal)

				var latestValue: Int?
				var completed = false
				var errored = false

				newSignal.start(next: {
					latestValue = $0
				}, error: { _ in
					errored = true
				}, completed: {
					completed = true
				})

				expect(latestValue).to(beNil())
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				scheduler.advanceByInterval(1.5)
				expect(latestValue).to(equal(0))
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				scheduler.advanceByInterval(1)
				expect(latestValue).to(equal(1))
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				triggerSink.put(())
				expect(latestValue).to(equal(1))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())

				scheduler.run()
				expect(latestValue).to(equal(1))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}

			it("should not take any values if the trigger fires immediately") {
				let signal = ColdSignal.fromValues([ 0, 1, 2 ])
				let (triggerSignal, triggerSink) = HotSignal<()>.pipe()
				let newSignal = signal.takeUntil(triggerSignal)

				triggerSink.put(())

				var latestValue: Int?
				var completed = false
				var errored = false

				newSignal.start(next: {
					latestValue = $0
				}, error: { _ in
					errored = true
				}, completed: {
					completed = true
				})

				expect(latestValue).to(beNil())
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}
		}

		describe("takeWhile") {
			it("should take until the predicate is false") {
				let values = ColdSignal
					.fromValues([ 0, 2, 1, 3, 4 ])
					.takeWhile { $0 % 2 == 0 }
					.collect()

				expect(values).to(equal([ 0, 2 ]))
			}
		}

		describe("deliverOn") {
			it("should deliver all events on the given scheduler") {
				let scheduler = TestScheduler()

				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				ColdSignal
					.fromValues([ 0, 1, 2 ])
					.deliverOn(scheduler)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([]))
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				scheduler.advance()

				expect(receivedValues).to(equal([ 0, 1, 2 ]))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}
		}

		describe("evaluateOn") {
			it("should evaluate the generator on the given scheduler") {
				var started = false
				let signal = ColdSignal<()> { (sink, disposable) in
					started = true
					sink.put(.Completed)
				}

				let scheduler = TestScheduler()

				var receivedValue = false
				var errored = false
				var completed = false

				signal
					.evaluateOn(scheduler)
					.start(next: { _ in
						receivedValue = true
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValue).to(beFalsy())
				expect(started).to(beFalsy())
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				scheduler.advance()

				expect(receivedValue).to(beFalsy())
				expect(started).to(beTruthy())
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}
		}

		describe("delay") {
			it("should delay next and completed events by the given interval") {
				let scheduler = TestScheduler()

				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				ColdSignal
					.fromValues([ 0, 1, 2, 3 ])
					.delay(1, onScheduler: scheduler)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([]))
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				scheduler.advanceByInterval(0.5)
				expect(receivedValues).to(equal([]))
				expect(completed).to(beFalsy())
				expect(errored).to(beFalsy())

				scheduler.advanceByInterval(0.6)
				expect(receivedValues).to(equal([ 0, 1, 2, 3 ]))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}

			it("should schedule error events immediately") {
				let scheduler = TestScheduler()

				let testError = RACError.Empty.error
				var receivedError: NSError?

				ColdSignal<()>.error(testError)
					.delay(1, onScheduler: scheduler)
					.start(error: { error in
						receivedError = error
					})

				expect(receivedError).to(beNil())

				scheduler.advance()
				expect(receivedError).to(equal(testError))
			}
		}

		describe("timeoutWithError") {
			let testError = RACError.Empty.error

			it("should do nothing if the signal completes before the timeout") {
				let scheduler = TestScheduler()

				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				ColdSignal
					.fromValues([ 0, 1, 2, 3 ])
					.timeoutWithError(testError, afterInterval: 1, onScheduler: scheduler)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ 0, 1, 2, 3 ]))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())

				scheduler.run()
				expect(receivedValues).to(equal([ 0, 1, 2, 3 ]))
				expect(completed).to(beTruthy())
				expect(errored).to(beFalsy())
			}

			it("should error if the timeout elapses") {
				let scheduler = TestScheduler()
				var receivedError: NSError?

				ColdSignal<()>.never()
					.timeoutWithError(testError, afterInterval: 1, onScheduler: scheduler)
					.start(error: { error in
						receivedError = error
					})

				expect(receivedError).to(beNil())

				scheduler.advanceByInterval(0.5)
				expect(receivedError).to(beNil())

				scheduler.advanceByInterval(0.6)
				expect(receivedError).to(equal(testError))
			}
		}

		describe("on") {
			it("should invoke closures for events in a successful signal") {
				var startedCallback = false
				var eventCallbacks: [String] = []
				var nextCallbacks: [Int] = []
				var errorCallback: NSError?
				var completedCallback = false
				var terminatedCallback = false
				var disposedCallback = false

				var started = false
				var disposed = false
				let signal = ColdSignal<Int> { (sink, disposable) in
					expect(startedCallback).to(beTruthy())
					started = true

					disposable.addDisposable {
						expect(disposedCallback).to(beFalsy())
						disposed = true
					}

					expect(eventCallbacks).to(equal([]))
					expect(nextCallbacks).to(equal([]))

					sink.put(.Next(Box(0)))
					expect(eventCallbacks).to(equal([ "next" ]))
					expect(nextCallbacks).to(equal([ 0 ]))

					expect(completedCallback).to(beFalsy())
					expect(terminatedCallback).to(beFalsy())

					sink.put(.Completed)
					expect(eventCallbacks).to(equal([ "next", "completed" ]))
					expect(completedCallback).to(beTruthy())
					expect(terminatedCallback).to(beTruthy())
				}

				signal.on(started: {
					startedCallback = true
				}, event: { ev in
					let name = ev.event(ifNext: { _ in "next" }, ifError: { _ in "error" }, ifCompleted: "completed")
					eventCallbacks.append(name)
				}, next: {
					expect(eventCallbacks.count).to(equal(nextCallbacks.count + 1))
					nextCallbacks.append($0)
				}, error: {
					errorCallback = $0
				}, completed: {
					expect(terminatedCallback).to(beFalsy())
					completedCallback = true
				}, terminated: {
					expect(completedCallback).to(beTruthy())
					terminatedCallback = true
				}, disposed: {
					expect(completedCallback).to(beTruthy())
					expect(terminatedCallback).to(beTruthy())
					disposedCallback = true
				}).start()

				expect(startedCallback).to(beTruthy())
				expect(eventCallbacks).to(equal([ "next", "completed" ]))
				expect(nextCallbacks).to(equal([ 0 ]))
				expect(errorCallback).to(beNil())
				expect(completedCallback).to(beTruthy())
				expect(terminatedCallback).to(beTruthy())
				expect(disposedCallback).to(beTruthy())
			}

			it("should invoke closures for events in an erroneous signal") {
				var startedCallback = false
				var eventCallbacks: [String] = []
				var nextCallbacks: [Int] = []
				var errorCallback: NSError?
				var completedCallback = false
				var terminatedCallback = false
				var disposedCallback = false

				let testError = RACError.Empty.error

				var started = false
				var disposed = false
				let signal = ColdSignal<Int> { (sink, disposable) in
					expect(startedCallback).to(beTruthy())
					started = true

					disposable.addDisposable {
						expect(disposedCallback).to(beFalsy())
						disposed = true
					}

					expect(eventCallbacks).to(equal([]))
					expect(nextCallbacks).to(equal([]))

					sink.put(.Error(testError))
					expect(eventCallbacks).to(equal([ "error" ]))
					expect(terminatedCallback).to(beTruthy())
				}

				signal.on(started: {
					startedCallback = true
				}, event: { ev in
					let name = ev.event(ifNext: { _ in "next" }, ifError: { _ in "error" }, ifCompleted: "completed")
					eventCallbacks.append(name)
				}, next: {
					expect(eventCallbacks.count).to(equal(nextCallbacks.count + 1))
					nextCallbacks.append($0)
				}, error: {
					expect(terminatedCallback).to(beFalsy())
					errorCallback = $0
				}, completed: {
					completedCallback = true
				}, terminated: {
					expect(errorCallback).notTo(beNil())
					terminatedCallback = true
				}, disposed: {
					expect(errorCallback).notTo(beNil())
					expect(terminatedCallback).to(beTruthy())
					disposedCallback = true
				}).start()

				expect(startedCallback).to(beTruthy())
				expect(eventCallbacks).to(equal([ "error" ]))
				expect(nextCallbacks).to(equal([]))
				expect(errorCallback).to(equal(testError))
				expect(completedCallback).to(beFalsy())
				expect(terminatedCallback).to(beTruthy())
				expect(disposedCallback).to(beTruthy())
			}
		}

		describe("try") {
			let testError = RACError.Empty.error

			it("should forward an error upon failure") {
				let result = ColdSignal.single(0)
					.try { value, error in
						error.memory = testError
						return false
					}
					.first()

				expect(result.error()).to(equal(testError))
			}

			it("should forward the original value upon success") {
				let result = ColdSignal.single(0)
					.try { value, error in
						// This should have no effect.
						error.memory = testError

						return true
					}
					.first()

				expect(result.value()).to(equal(0))
			}
		}

		describe("tryMap") {
			let testError = RACError.Empty.error

			describe("with an error pointer") {
				it("should forward an error upon failure") {
					let result = ColdSignal.single(0)
						.tryMap { value, error -> Int? in
							error.memory = testError
							return nil
						}
						.first()

					expect(result.error()).to(equal(testError))
				}

				it("should forward the mapped value upon success") {
					let result = ColdSignal.single(0)
						.tryMap { value, error -> Int? in
							// This should have no effect.
							error.memory = testError

							return value + 1
						}
						.first()

					expect(result.value()).to(equal(1))
				}
			}

			describe("with a Result") {
				it("should forward an error upon failure") {
					let result = ColdSignal.single(0)
						.tryMap { value in Result<Int>.Failure(testError) }
						.first()

					expect(result.error()).to(equal(testError))
				}

				it("should forward the mapped value upon success") {
					let result = ColdSignal.single(0)
						.tryMap { value in  Result<Int>.Success(Box(value + 1)) }
						.first()

					expect(result.value()).to(equal(1))
				}
			}
		}

		describe("catch") {
			it("should switch to the given signal upon error") {
				let testError = RACError.Empty.error
				let signal = ColdSignal<Int> { (sink, disposable) in
					sink.put(.Next(Box(0)))
					sink.put(.Error(testError))
				}

				let values = signal
					.catch { error in
						expect(error).to(equal(testError))
						return ColdSignal.single(1)
					}
					.collect()

				expect(values).to(equal([ 0, 1 ]))
			}
		}

		describe("materialize") {
			it("should yield Event values") {
				let signal = ColdSignal<Int> { (sink, disposable) in
					sink.put(.Next(Box(0)))
					sink.put(.Error(RACError.Empty.error))
				}

				let values = signal
					.materialize()
					.map { ev -> String in
						return ev.event(ifNext: { value in
							return value.description
						}, ifError: { error in
							return "error"
						}, ifCompleted: "completed")
					}
					.collect()

				expect(values).to(equal([ "0", "error" ]))
			}
		}

		describe("dematerialize") {
			it("should transform Event values into real events") {
				var receivedValues: [Int] = []
				var receivedError: NSError?
				var completed = false

				let testError = RACError.Empty.error

				ColdSignal
					.fromValues([ Event.Next(Box(0)), Event.Next(Box(1)), Event.Error(testError) ])
					.dematerialize(identity)
					.start(next: {
						receivedValues.append($0)
					}, error: { error in
						receivedError = error
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ 0, 1 ]))
				expect(receivedError).to(equal(testError))
				expect(completed).to(beFalsy())
			}
		}

		describe("combineLatestWith") {
			it("should forward the latest values from both inputs") {
				let scheduler = TestScheduler()
				let firstSignal = ColdSignal<Int> { (sink, disposable) in
					sink.put(.Next(Box(1)))

					scheduler.schedule {
						sink.put(.Next(Box(2)))
						sink.put(.Next(Box(3)))
						sink.put(.Completed)
					}
				}

				let secondSignal = ColdSignal.fromValues([ "foo", "bar" ])

				var receivedValues: [String] = []
				var errored = false
				var completed = false

				firstSignal
					.combineLatestWith(secondSignal)
					.map { num, str in "\(num)\(str)" }
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ "1foo", "1bar" ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beFalsy())

				scheduler.run()
				expect(receivedValues).to(equal([ "1foo", "1bar", "2bar", "3bar" ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beTruthy())
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

		describe("merge") {
			it("should send values from inner signals as they arrive") {
				let scheduler = TestScheduler()
				let signal = ColdSignal<ColdSignal<Int>> { (sink, disposable) in
					sink.put(.Next(Box(ColdSignal.single(0))))

					let firstSignal = ColdSignal<Int> { (sink, disposable) in
						sink.put(.Next(Box(1)))

						scheduler.schedule {
							sink.put(.Next(Box(3)))

							scheduler.schedule {
								sink.put(.Completed)
							}
						}
					}

					let secondSignal = ColdSignal<Int> { (sink, disposable) in
						sink.put(.Next(Box(2)))

						scheduler.schedule {
							sink.put(.Next(Box(4)))
							sink.put(.Completed)
						}
					}

					sink.put(.Next(Box(firstSignal)))
					sink.put(.Next(Box(secondSignal)))
					sink.put(.Completed)
				}

				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				signal
					.merge(identity)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ 0, 1, 2 ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beFalsy())

				scheduler.run()
				expect(receivedValues).to(equal([ 0, 1, 2, 3, 4 ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beTruthy())
			}
		}

		describe("switchToLatest") {
			it("should send values from the latest inner signal") {
				let scheduler = TestScheduler()
				let signal = ColdSignal<ColdSignal<Int>> { (sink, disposable) in
					sink.put(.Next(Box(ColdSignal.single(0))))

					let firstSignal = ColdSignal<Int> { (sink, disposable) in
						sink.put(.Next(Box(1)))

						scheduler.schedule {
							sink.put(.Next(Box(3)))
							sink.put(.Completed)
						}
					}

					let secondSignal = ColdSignal<Int> { (sink, disposable) in
						sink.put(.Next(Box(2)))

						scheduler.schedule {
							sink.put(.Next(Box(4)))
							sink.put(.Completed)
						}
					}

					sink.put(.Next(Box(firstSignal)))
					sink.put(.Next(Box(secondSignal)))
					sink.put(.Completed)
				}

				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				signal
					.switchToLatest(identity)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ 0, 1, 2 ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beFalsy())

				scheduler.run()
				expect(receivedValues).to(equal([ 0, 1, 2, 4 ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beTruthy())
			}
		}

		describe("concat") {
			it("should send values from each inner signal in order") {
				let scheduler = TestScheduler()
				let signal = ColdSignal<ColdSignal<Int>> { (sink, disposable) in
					sink.put(.Next(Box(ColdSignal.single(0))))

					let firstSignal = ColdSignal<Int> { (sink, disposable) in
						sink.put(.Next(Box(1)))

						scheduler.schedule {
							sink.put(.Next(Box(3)))

							scheduler.schedule {
								sink.put(.Completed)
							}
						}
					}

					let secondSignal = ColdSignal<Int> { (sink, disposable) in
						sink.put(.Next(Box(2)))

						scheduler.schedule {
							sink.put(.Next(Box(4)))
							sink.put(.Completed)
						}
					}

					sink.put(.Next(Box(firstSignal)))
					sink.put(.Next(Box(secondSignal)))
					sink.put(.Completed)
				}

				var receivedValues: [Int] = []
				var errored = false
				var completed = false

				signal
					.concat(identity)
					.start(next: {
						receivedValues.append($0)
					}, error: { _ in
						errored = true
					}, completed: {
						completed = true
					})

				expect(receivedValues).to(equal([ 0, 1 ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beFalsy())

				scheduler.run()
				expect(receivedValues).to(equal([ 0, 1, 3, 2, 4 ]))
				expect(errored).to(beFalsy())
				expect(completed).to(beTruthy())
			}

			it("should concatenate one signal after another") {
				let values = ColdSignal.fromValues([ 0, 1, 2 ])
					.concat(ColdSignal.fromValues([ 3, 4, 5 ]))
					.collect()

				expect(values).to(equal([ 0, 1, 2, 3, 4, 5 ]))
			}
		}

		describe("then") {
			it("should ignore the first signal's values and forward the second") {
				var started = false
				var completed = false

				let values = ColdSignal.fromValues([ "foo", "bar" ])
					.on(started: {
						started = true
					}, completed: {
						completed = true
					})
					.then(ColdSignal.fromValues([ 3, 4, 5 ]))
					.collect()

				expect(started).to(beTruthy())
				expect(completed).to(beTruthy())
				expect(values).to(equal([ 3, 4, 5 ]))
			}
		}

		describe("first") {
			it("should return the first value sent, then dispose of the signal") {
				var completed = false
				var disposed = false

				let result = ColdSignal
					.fromValues([ 0, 1, 2 ])
					.on(completed: {
						completed = true
					}, disposed: {
						disposed = true
					})
					.first()

				expect(result.value()).to(equal(0))
				expect(completed).to(beFalsy())
				expect(disposed).to(beTruthy())
			}

			it("should return an error if no values are sent") {
				let result = ColdSignal<()>.empty().first()
				expect(result.error()).to(equal(RACError.ExpectedCountMismatch.error))
			}
		}

		describe("last") {
			it("should return the last value sent after completion") {
				var completed = false

				let result = ColdSignal
					.fromValues([ 0, 1, 2 ])
					.on(completed: {
						completed = true
					})
					.last()

				expect(result.value()).to(equal(2))
				expect(completed).to(beTruthy())
			}

			it("should return an error if no values are sent") {
				let result = ColdSignal<()>.empty().last()
				expect(result.error()).to(equal(RACError.ExpectedCountMismatch.error))
			}
		}

		describe("single") {
			it("should return the only value sent after completion") {
				var completed = false

				let result = ColdSignal
					.single(0)
					.on(completed: {
						completed = true
					})
					.single()

				expect(result.value()).to(equal(0))
				expect(completed).to(beTruthy())
			}

			it("should return an error if no values are sent") {
				let result = ColdSignal<()>.empty().single()
				expect(result.error()).to(equal(RACError.ExpectedCountMismatch.error))
			}

			it("should return an error if too many values are sent") {
				let result = ColdSignal
					.fromValues([ 0, 1, 2 ])
					.single()

				expect(result.error()).to(equal(RACError.ExpectedCountMismatch.error))
			}
		}

		describe("wait") {
			it("should return success if the signal completes") {
				let result = ColdSignal
					.fromValues([ 0, 1, 2 ])
					.wait()

				expect(result.isSuccess()).to(beTruthy())
			}

			it("should return an error if the signal errors") {
				let testError = RACError.Empty.error
				let result = ColdSignal<()>.error(testError).wait()
				expect(result.error()).to(equal(testError))
			}
		}

		describe("startMulticasted") {
			it("should forward values then invoke completion handler") {
				let scheduler = TestScheduler()
				let signal = ColdSignal<Int> { (sink, disposable) in
					scheduler.schedule {
						sink.put(.Next(Box(0)))
						sink.put(.Next(Box(1)))
						sink.put(.Next(Box(2)))
						sink.put(.Completed)
					}

					return
				}

				var completed = false
				let hotSignal = signal.startMulticasted(errorHandler: nil) {
					completed = true
				}

				var receivedValues: [Int] = []
				hotSignal.observe { receivedValues.append($0) }

				expect(receivedValues).to(equal([]))
				expect(completed).to(beFalsy())

				scheduler.advance()
				expect(receivedValues).to(equal([ 0, 1, 2 ]))
				expect(completed).to(beTruthy())
			}

			it("should forward values then invoke error handler") {
				let scheduler = TestScheduler()
				let testError = RACError.Empty.error

				let signal = ColdSignal<Int> { (sink, disposable) in
					scheduler.schedule {
						sink.put(.Next(Box(0)))
						sink.put(.Next(Box(1)))
						sink.put(.Next(Box(2)))
						sink.put(.Error(testError))
					}

					return
				}

				var completed = false
				var receivedError: NSError?

				let hotSignal = signal.startMulticasted(errorHandler: { error in
					receivedError = error
				}, completionHandler: {
					completed = true
				})

				var receivedValues: [Int] = []
				hotSignal.observe { receivedValues.append($0) }

				expect(receivedValues).to(equal([]))
				expect(receivedError).to(beNil())
				expect(completed).to(beFalsy())

				scheduler.advance()
				expect(receivedValues).to(equal([ 0, 1, 2 ]))
				expect(receivedError).to(equal(testError))
				expect(completed).to(beFalsy())
			}
		}
	}
}
