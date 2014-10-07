//
//  SignalSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-01.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import Nimble
import Quick
import ReactiveCocoa

class SignalSpec: QuickSpec {
	override func spec() {
		describe("instantiation") {
			it("should instantiate with a constant value") {
				let signal = Signal.constant(42)
				expect(signal.current).to(equal(42))

				var observedValue: Int? = nil
				signal.observe { observedValue = $0 }
				expect(observedValue).to(equal(42))
			}

			it("should instantiate with a custom generator") {
				let queue = dispatch_queue_create("com.github.ReactiveCocoa.SignalSpec", DISPATCH_QUEUE_SERIAL)
				dispatch_suspend(queue)

				let signal = Signal(initialValue: 0) { sink in
					dispatch_async(queue) {
						for i in 1...3 {
							sink.put(i)
						}
					}
				}

				expect(signal.current).to(equal(0))

				var observedValues: [Int] = []
				signal.observe(observedValues.append)
				expect(observedValues).to(equal([ 0 ]))

				dispatch_resume(queue)
				dispatch_sync(queue) {}
				expect(observedValues).to(equal([ 0, 1, 2, 3 ]))
			}

			it("should instantiate a pipe") {
				let (signal, sink) = Signal.pipeWithInitialValue(0)
				expect(signal.current).to(equal(0))

				var observedValues: [Int] = []
				signal.observe(observedValues.append)
				expect(observedValues).to(equal([ 0 ]))

				sink.put(1)
				expect(signal.current).to(equal(1))
				expect(observedValues).to(equal([ 0, 1 ]))

				sink.put(2)
				expect(signal.current).to(equal(2))
				expect(observedValues).to(equal([ 0, 1, 2 ]))
			}
		}

		describe("interval") {
			var scheduler: TestScheduler!

			beforeEach {
				scheduler = TestScheduler()
			}

			it("should fire on the given interval") {
				let signal = Signal<NSDate>.interval(1, onScheduler: scheduler!)

				var observedDates = 0
				signal.observe { _ in
					observedDates++
					return ()
				}

				expect(observedDates).to(equal(1))
				expect(signal.current).to(equal(scheduler.currentDate))

				scheduler.advanceByInterval(2.5)
				expect(observedDates).to(equal(3))
				expect(signal.current).to(equal(scheduler.currentDate))

				scheduler.advanceByInterval(1)
				expect(observedDates).to(equal(4))
				expect(signal.current).to(equal(scheduler.currentDate))
			}
		}

		describe("optional unwrapping") {
			var optionalsSignal: Signal<Int?>!
			var optionalsSink: SinkOf<Int?>!

			beforeEach {
				let (signal, sink) = Signal<Int?>.pipeWithInitialValue(nil)
				optionalsSignal = signal
				optionalsSink = sink

				expect(optionalsSignal.current).to(beNil())
			}

			it("should safely unwrap optionals") {
				let unwrapped = optionalsSignal.unwrapOptionals(identity, initialValue: 0)
				expect(unwrapped.current).to(equal(0))

				optionalsSink.put(1)
				expect(unwrapped.current).to(equal(1))

				optionalsSink.put(nil)
				expect(unwrapped.current).to(equal(1))

				optionalsSink.put(5)
				expect(unwrapped.current).to(equal(5))
			}

			it("should forcibly unwrap optionals") {
				optionalsSink.put(0)

				let unwrapped = optionalsSignal.forceUnwrapOptionals(identity)
				expect(unwrapped.current).to(equal(0))

				optionalsSink.put(1)
				expect(unwrapped.current).to(equal(1))
			}
		}

		describe("signals of signals") {
			var signalsSignal: Signal<Signal<Int>>!
			var signalsSink: SinkOf<Signal<Int>>!

			beforeEach {
				let (signal, sink) = Signal.pipeWithInitialValue(Signal.constant(0))
				signalsSignal = signal
				signalsSink = sink

				expect(signalsSignal.current.current).to(equal(0))
			}

			it("should merge") {
				let merged = signalsSignal.merge(identity)
				expect(merged.current).to(equal(0))

				let (firstSignal, firstSink) = Signal.pipeWithInitialValue(1)
				signalsSink.put(firstSignal)
				expect(merged.current).to(equal(1))

				let (secondSignal, secondSink) = Signal.pipeWithInitialValue(2)
				signalsSink.put(secondSignal)
				expect(merged.current).to(equal(2))

				firstSink.put(5)
				expect(merged.current).to(equal(5))

				secondSink.put(10)
				expect(merged.current).to(equal(10))

				let (thirdSignal, thirdSink) = Signal.pipeWithInitialValue(15)
				signalsSink.put(thirdSignal)
				expect(merged.current).to(equal(15))

				secondSink.put(20)
				expect(merged.current).to(equal(20))
			}

			it("should switch") {
				let switched = signalsSignal.switchToLatest(identity)
				expect(switched.current).to(equal(0))

				let (firstSignal, firstSink) = Signal.pipeWithInitialValue(1)
				signalsSink.put(firstSignal)
				expect(switched.current).to(equal(1))

				let (secondSignal, secondSink) = Signal.pipeWithInitialValue(2)
				signalsSink.put(secondSignal)
				expect(switched.current).to(equal(2))

				firstSink.put(5)
				expect(switched.current).to(equal(2))

				secondSink.put(10)
				expect(switched.current).to(equal(10))

				let (thirdSignal, thirdSink) = Signal.pipeWithInitialValue(15)
				signalsSink.put(thirdSignal)
				expect(switched.current).to(equal(15))

				secondSink.put(20)
				expect(switched.current).to(equal(15))
			}
		}

		describe("value operations") {
			var signal: Signal<Int>!
			var sink: SinkOf<Int>!

			beforeEach {
				let (a, b) = Signal<Int>.pipeWithInitialValue(0)
				signal = a
				sink = b
			}

			describe("map") {
				it("should map values to other values") {
					let mapped = signal.map { $0.description }
					expect(mapped.current).to(equal("0"))

					sink.put(2)
					expect(mapped.current).to(equal("2"))

					sink.put(15)
					expect(mapped.current).to(equal("15"))
				}
			}

			describe("scan") {
				it("should scan and accumulate a value") {
					let accumulator = signal.scanWithStart([]) { $0 + [ $1 ] }
					expect(accumulator.current).to(equal([ 0 ]))

					sink.put(1)
					expect(accumulator.current).to(equal([ 0, 1 ]))

					sink.put(3)
					expect(accumulator.current).to(equal([ 0, 1, 3 ]))
				}
			}

			describe("take") {
				it("should stop after the given number of values") {
					let terminating = signal.take(2)
					expect(terminating.current).to(equal(0))

					sink.put(1)
					expect(terminating.current).to(equal(1))

					sink.put(2)
					expect(terminating.current).to(equal(1))
				}
			}

			describe("takeWhile") {
				it("should stop when a value fails") {
					let terminating = signal.takeWhile { $0 < 5 }
					expect(terminating.current).to(equal(0))

					sink.put(1)
					expect(terminating.current).to(equal(1))

					sink.put(2)
					expect(terminating.current).to(equal(2))

					sink.put(5)
					expect(terminating.current).to(equal(2))

					sink.put(3)
					expect(terminating.current).to(equal(2))
				}

				it("should stop immediately if the current value fails") {
					let terminating = signal.takeWhile { $0 > 0 }
					expect(terminating.current).to(beNil())

					sink.put(1)
					expect(terminating.current).to(beNil())
				}
			}

			describe("combinePrevious") {
				it("should combine each value with the previous") {
					let combined = signal.combinePreviousWithStart(-1)
					expect(combined.current.0).to(equal(-1))
					expect(combined.current.1).to(equal(0))

					sink.put(5)
					expect(combined.current.0).to(equal(0))
					expect(combined.current.1).to(equal(5))

					sink.put(6)
					expect(combined.current.0).to(equal(5))
					expect(combined.current.1).to(equal(6))
				}
			}

			describe("skip") {
				it("should nil out skipped values") {
					let skipped = signal.skip(2)
					expect(skipped.current).to(beNil())

					sink.put(0)
					expect(skipped.current).to(beNil())

					sink.put(0)
					expect(skipped.current).to(equal(0))

					sink.put(1)
					expect(skipped.current).to(equal(1))
				}
			}

			describe("skipWhile") {
				it("should nil out skipped values") {
					let skipped = signal.skipWhile { $0 < 2 }
					expect(skipped.current).to(beNil())

					sink.put(1)
					expect(skipped.current).to(beNil())

					sink.put(2)
					expect(skipped.current).to(equal(2))

					sink.put(1)
					expect(skipped.current).to(equal(1))
				}
			}

			describe("filter") {
				it("should nil values that fail the predicate") {
					let filtered = signal.filter { $0 >= 2 }
					expect(filtered.current).to(beNil())

					sink.put(1)
					expect(filtered.current).to(beNil())

					sink.put(2)
					expect(filtered.current).to(equal(2))

					sink.put(1)
					expect(filtered.current).to(beNil())
				}
			}

			describe("skipRepeats") {
				it("should ignore successive occurrences of the same value") {
					let skipped = signal.skipRepeats(identity)

					var values: [Int] = []
					skipped.observe(values.append)
					expect(values).to(equal([ 0 ]))

					sink.put(0)
					expect(values).to(equal([ 0 ]))

					sink.put(1)
					expect(values).to(equal([ 0, 1 ]))

					sink.put(1)
					expect(values).to(equal([ 0, 1 ]))

					sink.put(0)
					expect(values).to(equal([ 0, 1, 0 ]))
				}
			}
		}

		describe("buffer") {
			var signal: Signal<Int>!
			var sink: SinkOf<Int>!

			beforeEach {
				let (a, b) = Signal<Int>.pipeWithInitialValue(0)
				signal = a
				sink = b
			}

			it("should buffer an unlimited number of values") {
				let (producer, _) = signal.buffer()

				sink.put(1)
				sink.put(2)

				var values: [Int] = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([ 0, 1, 2 ]))

				sink.put(3)
				expect(values).to(equal([ 0, 1, 2, 3 ]))

				values = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([ 0, 1, 2, 3 ]))
			}

			it("should buffer a limited number of values") {
				let (producer, _) = signal.buffer(capacity: 2)

				sink.put(1)
				sink.put(2)

				var values: [Int] = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([ 1, 2 ]))

				sink.put(3)
				expect(values).to(equal([ 1, 2, 3 ]))

				values = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([ 2, 3 ]))
			}

			it("should allow buffering zero values") {
				let (producer, _) = signal.buffer(capacity: 0)

				sink.put(1)
				sink.put(2)

				var values: [Int] = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([]))

				sink.put(3)
				expect(values).to(equal([ 3 ]))

				values = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([]))
			}

			it("should stop buffering when disposed") {
				let (producer, disposable) = signal.buffer()

				sink.put(1)
				disposable.dispose()

				sink.put(2)

				var values: [Int] = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([ 0, 1 ]))

				sink.put(3)
				expect(values).to(equal([ 0, 1 ]))

				values = []
				producer.produce(Consumer(next: values.append))
				expect(values).to(equal([ 0, 1 ]))
			}
		}

		describe("combineLatestWith") {
			it("should combine the latest values from each input") {
				let (signal1, sink1) = Signal.pipeWithInitialValue(0)
				let (signal2, sink2) = Signal.pipeWithInitialValue("")

				let combined = signal1.combineLatestWith(signal2)
				expect(combined.current.0).to(equal(0))
				expect(combined.current.1).to(equal(""))

				sink1.put(1)
				expect(combined.current.0).to(equal(1))
				expect(combined.current.1).to(equal(""))

				sink1.put(2)
				expect(combined.current.0).to(equal(2))
				expect(combined.current.1).to(equal(""))

				sink2.put("foo")
				expect(combined.current.0).to(equal(2))
				expect(combined.current.1).to(equal("foo"))

				sink1.put(3)
				expect(combined.current.0).to(equal(3))
				expect(combined.current.1).to(equal("foo"))
			}
		}

		describe("sampleOn") {
			it("should sample the current value whenever the sampler fires") {
				let (signal, sink) = Signal.pipeWithInitialValue(0)
				let (samplerSignal, samplerSink) = Signal.pipeWithInitialValue(())

				var values: [Int] = []
				let sampled = signal.sampleOn(samplerSignal)

				sampled.observe(values.append)
				expect(values).to(equal([ 0 ]))

				sink.put(1)
				expect(values).to(equal([ 0 ]))

				sink.put(2)
				expect(values).to(equal([ 0 ]))

				samplerSink.put(())
				expect(values).to(equal([ 0, 2 ]))

				samplerSink.put(())
				expect(values).to(equal([ 0, 2, 2 ]))

				sink.put(3)
				expect(values).to(equal([ 0, 2, 2 ]))

				samplerSink.put(())
				expect(values).to(equal([ 0, 2, 2, 3 ]))
			}
		}

		describe("delay") {
			it("should wait the given interval before forwarding values") {
				let (signal, sink) = Signal.pipeWithInitialValue(0)

				let scheduler = TestScheduler()
				let delayed = signal.delay(1, onScheduler: scheduler)

				var values: [Int] = []
				delayed.observe { values.append($0 ?? -1) }
				expect(values).to(equal([ -1 ]))

				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ -1, 0 ]))

				sink.put(1)
				expect(values).to(equal([ -1, 0 ]))

				scheduler.advanceByInterval(1)
				expect(values).to(equal([ -1, 0, 1 ]))

				sink.put(2)
				sink.put(3)
				expect(values).to(equal([ -1, 0, 1 ]))

				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ -1, 0, 1, 2, 3 ]))
			}
		}

		describe("throttle") {
			var signal: Signal<Int>!
			var sink: SinkOf<Int>!

			var scheduler: TestScheduler!
			var throttled: Signal<Int?>!
			var values: [Int] = []

			beforeEach {
				let (a, b) = Signal<Int>.pipeWithInitialValue(0)
				signal = a
				sink = b

				scheduler = TestScheduler()
				throttled = signal.throttle(1, onScheduler: scheduler)

				values = []
				throttled.observe { values.append($0 ?? -1) }
			}

			it("should immediately schedule unthrottled values") {
				expect(values).to(equal([ -1 ]))

				scheduler.advance()
				expect(values).to(equal([ -1, 0 ]))

				scheduler.advanceByInterval(1.5)
				sink.put(1)
				expect(values).to(equal([ -1, 0 ]))

				scheduler.advance()
				expect(values).to(equal([ -1, 0, 1 ]))

				scheduler.advanceByInterval(5)
				sink.put(2)
				expect(values).to(equal([ -1, 0, 1 ]))

				scheduler.advance()
				expect(values).to(equal([ -1, 0, 1, 2 ]))
			}

			it("should forward the latest throttled value") {
				sink.put(1)
				sink.put(2)
				expect(values).to(equal([ -1 ]))

				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ -1, 2 ]))

				sink.put(3)
				scheduler.advanceByInterval(0.25)
				expect(values).to(equal([ -1, 2, 3 ]))

				sink.put(4)
				scheduler.advanceByInterval(0.25)
				expect(values).to(equal([ -1, 2, 3 ]))

				sink.put(5)
				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ -1, 2, 3, 5 ]))
			}
		}

		describe("deliverOn") {
			it("should immediately schedule each value") {
				let (signal, sink) = Signal.pipeWithInitialValue(0)

				let scheduler = TestScheduler()
				let scheduled = signal.deliverOn(scheduler)

				var values: [Int] = []
				scheduled.observe { values.append($0 ?? -1) }
				expect(values).to(equal([ -1 ]))

				scheduler.advance()
				expect(values).to(equal([ -1, 0 ]))

				sink.put(1)
				sink.put(2)
				sink.put(3)
				expect(values).to(equal([ -1, 0 ]))

				scheduler.advance()
				expect(values).to(equal([ -1, 0, 1, 2, 3 ]))
			}
		}
	}
}
