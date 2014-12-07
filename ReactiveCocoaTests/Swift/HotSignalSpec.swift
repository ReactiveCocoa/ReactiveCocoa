//
//  HotSignalSpec.swift
//  ReactiveCocoa
//
//  Created by Alan Rogers on 30/10/2014.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveCocoa

class HotSignalSpec: QuickSpec {
	override func spec() {
		describe("pipe") {
			it("should forward values sent to the sink") {
				let (signal, sink) = HotSignal<Int>.pipe()

				var lastValue: Int?
				signal.observe { lastValue = $0 }

				expect(lastValue).to(beNil())

				sink.put(1)
				expect(lastValue).to(equal(1))

				var otherLastValue: Int?
				signal.observe { otherLastValue = $0 }

				expect(lastValue).to(equal(1))
				expect(otherLastValue).to(beNil())

				sink.put(2)
				expect(lastValue).to(equal(2))
				expect(otherLastValue).to(equal(2))
			}
		}

		describe("interval") {
			it("should fire at the given interval") {
				let scheduler = TestScheduler()
				let signal = HotSignal<NSDate>.interval(1, onScheduler: scheduler, withLeeway: 0)

				var fireCount = 0
				signal.observe { date in
					expect(date).to(equal(scheduler.currentDate))
					fireCount++
				}

				expect(fireCount).to(equal(0))

				scheduler.advanceByInterval(1.5)
				expect(fireCount).to(equal(1))

				scheduler.advanceByInterval(1)
				expect(fireCount).to(equal(2))

				scheduler.advanceByInterval(2)
				expect(fireCount).to(equal(4))

				scheduler.advanceByInterval(0.1)
				expect(fireCount).to(equal(4))
			}
		}

		describe("map") {
			it("should transform the values of the signal") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.map { $0 * 2 }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(1)
				expect(latestValue).to(equal(2))

				sink.put(3)
				expect(latestValue).to(equal(6))
			}
		}

		describe("filter") {
			it("should omit values from the signal") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.filter { $0 % 2 == 0 }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(1)
				expect(latestValue).to(beNil())

				sink.put(2)
				expect(latestValue).to(equal(2))

				sink.put(3)
				expect(latestValue).to(equal(2))

				sink.put(4)
				expect(latestValue).to(equal(4))
			}
		}

		describe("scan") {
			it("should accumulate a value") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.scan(initial: 0) { $0 + $1 }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(1)
				expect(latestValue).to(equal(1))

				sink.put(2)
				expect(latestValue).to(equal(3))

				sink.put(3)
				expect(latestValue).to(equal(6))
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.skip(2)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(1)
				expect(latestValue).to(beNil())

				sink.put(2)
				expect(latestValue).to(beNil())

				sink.put(3)
				expect(latestValue).to(equal(3))
			}

			it("should not skip any values when 0") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.skip(0)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(1)
				expect(latestValue).to(equal(1))
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.skipRepeats(identity)

				var count = 0
				newSignal.observe { _ in
					count++
					return ()
				}

				expect(count).to(equal(0))

				sink.put(3)
				expect(count).to(equal(1))

				sink.put(3)
				expect(count).to(equal(1))

				sink.put(5)
				expect(count).to(equal(2))
			}

			it("should skip values according to a predicate") {
				let (signal, sink) = HotSignal<[Int]>.pipe()
				let newSignal = signal.skipRepeats { $0 == $1 }

				var count = 0
				newSignal.observe { _ in
					count++
					return ()
				}

				expect(count).to(equal(0))

				sink.put([ 0 ])
				expect(count).to(equal(1))

				sink.put([ 0 ])
				expect(count).to(equal(1))

				sink.put([ 0, 1 ])
				expect(count).to(equal(2))
			}
		}

		describe("skipWhile") {
			it("should skip while the predicate is true") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.skipWhile { $0 % 2 == 0 }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(beNil())

				sink.put(2)
				expect(latestValue).to(beNil())

				sink.put(3)
				expect(latestValue).to(equal(3))

				sink.put(4)
				expect(latestValue).to(equal(4))
			}

			it("should not skip any values when the predicate starts false") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.skipWhile { _ in false }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(equal(0))

				sink.put(1)
				expect(latestValue).to(equal(1))
			}
		}

		describe("take") {
			it("should take initial values") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.take(2)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(equal(0))

				sink.put(1)
				expect(latestValue).to(equal(1))

				sink.put(2)
				expect(latestValue).to(equal(1))
			}

			it("should not take any values when 0") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.take(0)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(beNil())
			}
		}

		describe("takeUntil") {
			it("should take values until the trigger fires") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let (triggerSignal, triggerSink) = HotSignal<()>.pipe()
				let newSignal = signal.takeUntil(triggerSignal)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(equal(0))

				sink.put(1)
				expect(latestValue).to(equal(1))

				triggerSink.put(())

				sink.put(2)
				expect(latestValue).to(equal(1))
			}

			it("should not take any values if the trigger fires immediately") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let (triggerSignal, triggerSink) = HotSignal<()>.pipe()
				let newSignal = signal.takeUntil(triggerSignal)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				triggerSink.put(())

				sink.put(0)
				expect(latestValue).to(beNil())
			}
		}

		describe("takeUntilReplacement") {
			it("should take values from the original then the replacement") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let (replacementSignal, replacementSink) = HotSignal<Int>.pipe()
				let newSignal = signal.takeUntilReplacement(replacementSignal)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(equal(0))

				sink.put(1)
				expect(latestValue).to(equal(1))

				replacementSink.put(2)
				expect(latestValue).to(equal(2))

				sink.put(3)
				expect(latestValue).to(equal(2))

				replacementSink.put(4)
				expect(latestValue).to(equal(4))
			}
		}

		describe("takeWhile") {
			it("should take while the predicate is true") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.takeWhile { $0 % 2 == 0 }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(equal(0))

				sink.put(2)
				expect(latestValue).to(equal(2))

				sink.put(3)
				expect(latestValue).to(equal(2))

				sink.put(4)
				expect(latestValue).to(equal(2))
			}

			it("should not take any values when the predicate starts false") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let newSignal = signal.takeWhile { _ in false }

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(beNil())
			}
		}

		describe("deliverOn") {
			it("should send values on the given scheduler") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let scheduler = TestScheduler()
				let newSignal = signal.deliverOn(scheduler)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(beNil())

				scheduler.advance()
				expect(latestValue).to(equal(0))

				sink.put(1)
				expect(latestValue).to(equal(0))

				scheduler.advance()
				expect(latestValue).to(equal(1))
			}
		}

		describe("delay") {
			it("should send values on the given scheduler after the interval") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let scheduler = TestScheduler()
				let newSignal = signal.delay(1, onScheduler: scheduler)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				sink.put(0)
				expect(latestValue).to(beNil())

				scheduler.advanceByInterval(0.5)
				expect(latestValue).to(beNil())

				scheduler.advanceByInterval(1)
				expect(latestValue).to(equal(0))

				sink.put(1)
				sink.put(2)
				expect(latestValue).to(equal(0))

				scheduler.advanceByInterval(2.5)
				expect(latestValue).to(equal(2))
			}
		}

		describe("lifetime") {
			it("observe() should not keep signal alive") {
				let (outerSignal, outerSink) = HotSignal<Int>.pipe()

				weak var innerSignal: HotSignal<Int>?
				expect(innerSignal).to(beNil())

				var latestValue: Int?
				outerSignal.observe { latestValue = $0 }

				let createSignal = { () -> HotSignal<Int> in
					let (signal, sink) = HotSignal<Int>.pipe()
					innerSignal = signal

					expect(innerSignal).notTo(beNil())

					signal.observe(outerSink)
					expect(latestValue).to(beNil())

					sink.put(1)
					expect(latestValue).to(equal(1))

					return signal
				}

				expect(createSignal()).notTo(beNil())
				expect(innerSignal).to(beNil())
			}

			it("observe() disposable should keep signal alive") {
				let (outerSignal, outerSink) = HotSignal<Int>.pipe()

				weak var innerSignal: HotSignal<Int>?
				expect(innerSignal).to(beNil())

				var latestValue: Int?
				outerSignal.observe { latestValue = $0 }

				let createAndObserve = { () -> Disposable in
					let (signal, sink) = HotSignal<Int>.pipe()
					innerSignal = signal

					expect(innerSignal).notTo(beNil())

					let disposable = signal.observe(outerSink)
					expect(latestValue).to(beNil())

					sink.put(1)
					expect(latestValue).to(equal(1))

					return disposable
				}

				let disposable = createAndObserve()
				expect(innerSignal).notTo(beNil())

				disposable.dispose()

				// This fails non-deterministically, so it's probably ARC lulz.
				// However, the main point of the test is exercised with the
				// expectation above.
				//expect(innerSignal).toEventually(beNil())
			}

			it("generator should be disposed when signal is destroyed") {
				let disposable = SimpleDisposable()

				let createSignal = { () -> HotSignal<()> in
					return HotSignal<()> { _ in disposable }
				}

				expect(createSignal()).notTo(beNil())
				expect(disposable.disposed).to(beTruthy())
			}

			it("generator should not keep signal alive automatically") {
				let scheduler = TestScheduler()

				weak var innerSignal: HotSignal<NSDate>?
				expect(innerSignal).to(beNil())

				let createSignal = { () -> HotSignal<NSDate> in
					let signal = HotSignal<NSDate> { sink in
						scheduler.scheduleAfter(scheduler.currentDate, repeatingEvery: 1) {
							sink.put(scheduler.currentDate)
						}

						return nil
					}

					innerSignal = signal
					expect(innerSignal).notTo(beNil())

					return signal
				}

				expect(createSignal()).notTo(beNil())
				expect(innerSignal).to(beNil())
			}

			it("pipe() should keep signal alive while sink is") {
				let (outerSignal, outerSink) = HotSignal<Int>.pipe()

				func addSink() -> SinkOf<Int> {
					let (signal, sink) = HotSignal<Int>.pipe()
					signal.observe(outerSink)

					return sink
				}

				var latestValue: Int?
				outerSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				let innerSink = addSink()
				expect(latestValue).to(beNil())

				innerSink.put(1)
				expect(latestValue).to(equal(1))

				outerSink.put(2)
				expect(latestValue).to(equal(2))

				innerSink.put(3)
				expect(latestValue).to(equal(3))
			}
		}

		describe("replay") {
			var signal: HotSignal<Int>!
			var sink: SinkOf<Int>!
			var replaySignal: ColdSignal<Int>!

			beforeEach {
				let pipe = HotSignal<Int>.pipe()
				signal = pipe.0
				sink = pipe.1
			}

			describe("replay(0)") {
				beforeEach {
					replaySignal = signal.replay(0)
				}

				it("should not complete") {
					let error = RACError.Empty.error
					let scheduler = TestScheduler(startDate: NSDate())

					var receivedError: NSError? = nil
					replaySignal.timeoutWithError(error, afterInterval: 10, onScheduler:scheduler).start(error: { error in
						receivedError = error
					})

					scheduler.advanceByInterval(10)
					expect(receivedError).to(equal(error))
				}

				it("should forward values sent on the hot signal") {
					var collectedValues: [Int] = []
					replaySignal.start(next: {
						collectedValues += [ $0 ]
					})

					sink.put(9000)
					expect(collectedValues).to(equal([ 9000 ]))

					sink.put(40)
					expect(collectedValues).to(equal([ 9000, 40 ]))
				}
			}

			describe("replay(1)") {
				beforeEach {
					replaySignal = signal.replay(1)
				}

				it("should replay the first value") {
					sink.put(99)

					let result = replaySignal.first().value()
					expect(result).toNot(beNil())
					expect(result).to(equal(99))
				}

				it("should replay only the latest value") {
					sink.put(99)
					sink.put(400)

					var collectedValues: [Int] = []
					replaySignal.start(next: {
						collectedValues += [ $0 ]
					})

					expect(collectedValues).to(equal([ 400 ]))

					// New events should now be forwarded
					sink.put(50)
					expect(collectedValues).to(equal([ 400, 50 ]))
				}
			}

			describe("replay(2)") {
				beforeEach {
					replaySignal = signal.replay(2)
				}

				it("should replay the first 2 values") {
					sink.put(99)
					sink.put(400)

					let result = replaySignal
						.take(2)
						.reduce(initial: [] as [Int]) { (array, value) in
							return array + [ value ]
						}
						.first()
						.value()
					expect(result).toNot(beNil())
					expect(result).to(equal([99, 400]))
				}

				it("should replay only the latest values") {
					sink.put(99)
					sink.put(400)
					sink.put(9000)
					sink.put(77)

					var collectedValues: [Int] = []
					replaySignal.start(next: {
						collectedValues += [ $0 ]
					})

					expect(collectedValues).to(equal([ 9000, 77 ]))

					// New events should now be forwarded
					sink.put(50)
					expect(collectedValues).to(equal([ 9000, 77, 50 ]))
				}
			}
		}
	}
}
