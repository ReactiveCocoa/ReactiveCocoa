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
					replaySignal.start() { collectedValues += [ $0 ] }

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
					replaySignal.start() { collectedValues += [ $0 ] }

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
					replaySignal.start() { collectedValues += [ $0 ] }

					expect(collectedValues).to(equal([ 9000, 77 ]))

					// New events should now be forwarded
					sink.put(50)
					expect(collectedValues).to(equal([ 9000, 77, 50 ]))
				}
			}
		}
	}
}
