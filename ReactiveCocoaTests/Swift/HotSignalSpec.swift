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

			context("replay(0)") {
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
