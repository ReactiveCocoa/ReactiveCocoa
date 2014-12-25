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
			describe("signals initialized with init") {
				it("generator should keep signal alive while sink is") {
					weak var innerSignal: HotSignal<NSDate>?

					// Use an inner closure to help ARC deallocate things as we
					// expect.
					let test: () -> () = {
						let scheduler = TestScheduler()
						let signal = HotSignal<NSDate> { sink in
							scheduler.schedule {
								sink.put(scheduler.currentDate)
							}

							return
						}

						innerSignal = signal
						expect(innerSignal).notTo(beNil())

						scheduler.run()
					}

					test()
					expect(innerSignal).toEventually(beNil())
				}

				it("derived signals should stay alive until the original terminates") {
					let scheduler = TestScheduler()
					weak var originalSignal: HotSignal<()>?
					weak var derivedSignal: HotSignal<()>?

					var receivedValue = false
					let test: () -> () = {
						let signal = HotSignal<()> { sink in
							scheduler.schedule {
								sink.put(())
							}

							return
						}

						originalSignal = signal
						expect(originalSignal).notTo(beNil())

						derivedSignal = signal.take(1)
						expect(derivedSignal).notTo(beNil())

						derivedSignal?.observe { _ in receivedValue = true }
						return
					}

					test()
					expect(receivedValue).to(beFalsy())
					expect(originalSignal).notTo(beNil())
					expect(derivedSignal).notTo(beNil())

					scheduler.run()
					expect(receivedValue).to(beTruthy())
					expect(originalSignal).toEventually(beNil())
					expect(derivedSignal).toEventually(beNil())
				}
			}

			describe("weak signals") {
				it("observe() should not keep signal alive") {
					let (outerSignal, outerSink) = HotSignal<Int>.pipe()
					let scheduler = TestScheduler()

					weak var innerSignal: HotSignal<Int>?
					expect(innerSignal).to(beNil())

					var latestValue: Int?
					outerSignal.observe { latestValue = $0 }

					let createSignal = { () -> HotSignal<Int> in
						let signal = HotSignal<Int>.weak { sink in
							var value = 1

							return scheduler.scheduleAfter(1, repeatingEvery: 1) {
								sink.put(value++)
							}
						}

						innerSignal = signal
						expect(innerSignal).notTo(beNil())

						signal.observe(outerSink)
						expect(latestValue).to(beNil())

						scheduler.advanceByInterval(1.5)
						expect(latestValue).to(equal(1))

						scheduler.advanceByInterval(1)
						expect(latestValue).to(equal(2))

						return signal
					}

					expect(createSignal()).notTo(beNil())
					expect(innerSignal).to(beNil())

					scheduler.advanceByInterval(1)
					expect(latestValue).to(equal(2))
				}

				it("observe() disposable should keep signal alive") {
					weak var innerSignal: HotSignal<Int>?
					let scheduler = TestScheduler()

					var latestValue: Int?

					// Use an inner closure to help ARC deallocate things as we
					// expect.
					let test: () -> () = {
						let (outerSignal, outerSink) = HotSignal<Int>.pipe()
						outerSignal.observe { latestValue = $0 }

						let signal = HotSignal<Int>.weak { sink in
							var value = 1

							return scheduler.scheduleAfter(1, repeatingEvery: 1) {
								sink.put(value++)
							}
						}

						innerSignal = signal
						expect(innerSignal).notTo(beNil())

						let disposable = signal.observe(outerSink)
						expect(latestValue).to(beNil())

						scheduler.advanceByInterval(1.5)
						expect(latestValue).to(equal(1))
						expect(innerSignal).notTo(beNil())

						scheduler.advanceByInterval(1)
						expect(latestValue).to(equal(2))
						expect(innerSignal).notTo(beNil())

						disposable.dispose()
					}

					test()

					scheduler.advanceByInterval(1)
					expect(latestValue).to(equal(2))
					expect(innerSignal).toEventually(beNil())
				}

				it("generator should be disposed when signal is destroyed") {
					let disposable = SimpleDisposable()

					let createSignal = { () -> HotSignal<()> in
						return HotSignal<()>.weak { _ in disposable }
					}

					expect(createSignal()).notTo(beNil())
					expect(disposable.disposed).to(beTruthy())
				}

				it("derived signals should keep the original alive") {
					let scheduler = TestScheduler()
					weak var originalSignal: HotSignal<()>?
					weak var derivedSignal: HotSignal<()>?

					var receivedValue = false
					let test: () -> () = {
						let signal = HotSignal<()>.weak { sink in
							return scheduler.schedule {
								sink.put(())
							}
						}

						originalSignal = signal
						expect(originalSignal).notTo(beNil())

						derivedSignal = signal.take(1)
						expect(derivedSignal).notTo(beNil())

						derivedSignal?.observe { _ in receivedValue = true }
						return
					}

					test()
					expect(receivedValue).to(beFalsy())
					expect(originalSignal).notTo(beNil())
					expect(derivedSignal).notTo(beNil())

					scheduler.run()
					expect(receivedValue).to(beTruthy())
					expect(originalSignal).toEventually(beNil())
					expect(derivedSignal).toEventually(beNil())
				}
			}
		}

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

			it("should keep signal alive while sink is") {
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

			it("should stop sending values when the reference is lost") {
				let scheduler = TestScheduler()
				var fireCount = 0

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test: () -> () = {
					let signal = HotSignal<NSDate>.interval(1, onScheduler: scheduler, withLeeway: 0)

					signal.observe { date in
						expect(date).to(equal(scheduler.currentDate))
						fireCount++
					}

					expect(fireCount).to(equal(0))

					scheduler.advanceByInterval(1.5)
					expect(fireCount).to(equal(1))
				}

				test()

				scheduler.run()
				expect(fireCount).to(equal(1))
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

		describe("throttle") {
			it("should send values on the given scheduler at no less than the interval") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let scheduler = TestScheduler()
				let newSignal = signal.throttle(1, onScheduler: scheduler)

				var values: [Int] = []
				newSignal.observe { values.append($0) }

				expect(values).to(equal([]))

				sink.put(0)
				expect(values).to(equal([]))

				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				sink.put(1)
				scheduler.advance()
				expect(values).to(equal([ 0 ]))

				sink.put(2)
				sink.put(3)
				scheduler.advanceByInterval(1.5)
				expect(values).to(equal([ 0, 3 ]))

				sink.put(4)
				scheduler.advance()
				expect(values).to(equal([ 0, 3, 4 ]))
			}
		}

		describe("sampleOn") {
			it("should forward a value when the sampler fires") {
				let (signal, sink) = HotSignal<Int>.pipe()
				let (samplerSignal, samplerSink) = HotSignal<()>.pipe()
				let newSignal = signal.sampleOn(samplerSignal)

				var values: [Int] = []
				newSignal.observe { values.append($0) }

				expect(values).to(equal([]))

				samplerSink.put(())
				expect(values).to(equal([]))

				sink.put(0)
				expect(values).to(equal([]))

				samplerSink.put(())
				expect(values).to(equal([ 0 ]))

				sink.put(1)
				sink.put(2)
				samplerSink.put(())
				expect(values).to(equal([ 0, 2 ]))
			}
		}

		describe("combineLatestWith") {
			it("should forward the latest values from both inputs") {
				let (firstSignal, firstSink) = HotSignal<Int>.pipe()
				let (secondSignal, secondSink) = HotSignal<String>.pipe()
				let newSignal = firstSignal.combineLatestWith(secondSignal)

				var values: [String] = []
				newSignal.observe { (num, str) in
					values.append("\(num)\(str)")
				}

				expect(values).to(equal([]))

				firstSink.put(0)
				firstSink.put(1)
				expect(values).to(equal([]))

				secondSink.put("foo")
				expect(values).to(equal([ "1foo" ]))

				firstSink.put(2)
				expect(values).to(equal([ "1foo", "2foo" ]))

				secondSink.put("bar")
				secondSink.put("buzz")
				expect(values).to(equal([ "1foo", "2foo", "2bar", "2buzz" ]))
			}
		}

		describe("zipWith") {
			it("should combine pairs") {
				let (firstSignal, firstSink) = HotSignal<Int>.pipe()
				let (secondSignal, secondSink) = HotSignal<String>.pipe()
				let newSignal = firstSignal.zipWith(secondSignal)

				var values: [String] = []
				newSignal.observe { (num, str) in
					values.append("\(num)\(str)")
				}

				expect(values).to(equal([]))

				firstSink.put(1)
				firstSink.put(2)
				expect(values).to(equal([]))

				secondSink.put("foo")
				expect(values).to(equal([ "1foo" ]))

				firstSink.put(3)
				secondSink.put("bar")
				expect(values).to(equal([ "1foo", "2bar" ]))

				secondSink.put("buzz")
				expect(values).to(equal([ "1foo", "2bar", "3buzz" ]))

				secondSink.put("fuzz")
				expect(values).to(equal([ "1foo", "2bar", "3buzz" ]))

				firstSink.put(4)
				expect(values).to(equal([ "1foo", "2bar", "3buzz", "4fuzz" ]))
			}
		}

		describe("merge") {
			it("should forward values from any inner signals") {
				let (signal, sink) = HotSignal<HotSignal<Int>>.pipe()
				let newSignal = signal.merge(identity)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				let (firstSignal, firstSink) = HotSignal<Int>.pipe()
				let (secondSignal, secondSink) = HotSignal<Int>.pipe()

				firstSink.put(0)
				sink.put(firstSignal)
				expect(latestValue).to(beNil())

				firstSink.put(1)
				expect(latestValue).to(equal(1))

				sink.put(secondSignal)
				expect(latestValue).to(equal(1))

				secondSink.put(2)
				expect(latestValue).to(equal(2))

				firstSink.put(3)
				expect(latestValue).to(equal(3))

				firstSink.put(4)
				expect(latestValue).to(equal(4))
			}

			it("should release input signals when reference is lost") {
				weak var innerSignal: HotSignal<Int>?
				weak var mergedSignal: HotSignal<Int>?

				let test: () -> () = {
					let (signal, sink) = HotSignal<HotSignal<Int>>.pipe()
					let newSignal = signal.merge(identity)

					mergedSignal = newSignal
					expect(mergedSignal).notTo(beNil())

					var latestValue: Int?
					newSignal.observe { latestValue = $0 }

					expect(latestValue).to(beNil())

					let (firstSignal, firstSink) = HotSignal<Int>.pipe()
					innerSignal = firstSignal
					expect(innerSignal).notTo(beNil())

					sink.put(firstSignal)
					firstSink.put(0)
					expect(latestValue).to(equal(0))
				}

				test()
				expect(mergedSignal).toEventually(beNil())
				expect(innerSignal).toEventually(beNil())
			}
		}

		describe("merge(SequenceType)") {
			it("should forward values from any inner signals") {
				let (firstSignal, firstSink) = HotSignal<Int>.pipe()
				let (secondSignal, secondSink) = HotSignal<Int>.pipe()

				let newSignal = HotSignal.merge([firstSignal, secondSignal])
				
				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				firstSink.put(1)
				expect(latestValue).to(equal(1))

				secondSink.put(2)
				expect(latestValue).to(equal(2))

				firstSink.put(3)
				expect(latestValue).to(equal(3))

				firstSink.put(4)
				expect(latestValue).to(equal(4))
			}

			it("should release input signals when reference is lost") {
				weak var innerSignal: HotSignal<Int>?
				weak var mergedSignal: HotSignal<Int>?

				let test: () -> () = {
					let (firstSignal, firstSink) = HotSignal<Int>.pipe()
					let newSignal = HotSignal.merge([firstSignal])

					mergedSignal = newSignal
					expect(mergedSignal).notTo(beNil())

					var latestValue: Int?
					newSignal.observe { latestValue = $0 }

					expect(latestValue).to(beNil())

					innerSignal = firstSignal
					expect(innerSignal).notTo(beNil())

					firstSink.put(0)
					expect(latestValue).to(equal(0))
				}

				test()
				expect(mergedSignal).toEventually(beNil())
				expect(innerSignal).toEventually(beNil())
			}
		}

		describe("switchToLatest") {
			it("should forward values from the latest inner signal") {
				let (signal, sink) = HotSignal<HotSignal<Int>>.pipe()
				let newSignal = signal.switchToLatest(identity)

				var latestValue: Int?
				newSignal.observe { latestValue = $0 }

				expect(latestValue).to(beNil())

				let (firstSignal, firstSink) = HotSignal<Int>.pipe()
				let (secondSignal, secondSink) = HotSignal<Int>.pipe()

				firstSink.put(0)
				sink.put(firstSignal)
				expect(latestValue).to(beNil())

				firstSink.put(1)
				expect(latestValue).to(equal(1))

				sink.put(secondSignal)
				expect(latestValue).to(equal(1))

				secondSink.put(2)
				expect(latestValue).to(equal(2))

				firstSink.put(3)
				expect(latestValue).to(equal(2))

				secondSink.put(3)
				expect(latestValue).to(equal(3))
			}
		}

		describe("next") {
			it("should return the first value received") {
				let signal = HotSignal<NSDate>.interval(0.001, onScheduler: QueueScheduler(), withLeeway: 0)
				let date = signal.next()
				expect(date.earlierDate(NSDate())).to(equal(date))
			}
		}

		describe("buffer") {
			var signal: HotSignal<Int>!
			var sink: SinkOf<Int>!
			var bufferSignal: ColdSignal<Int>!

			beforeEach {
				let pipe = HotSignal<Int>.pipe()
				signal = pipe.0
				sink = pipe.1
			}

			describe("buffer(0)") {
				beforeEach {
					bufferSignal = signal.buffer(0)
				}

				it("should complete immediately") {
					var receivedValue = false
					var completed = false

					bufferSignal.start(next: { _ in
						receivedValue = true
					}, completed: {
						completed = true
					})

					expect(completed).to(beTruthy())
					expect(receivedValue).to(beFalsy())
				}
			}

			describe("buffer(2)") {
				beforeEach {
					bufferSignal = signal.buffer(2)
				}

				it("should yield two values received previously then complete") {
					sink.put(1)
					sink.put(2)

					let result = bufferSignal
						.reduce(initial: []) { $0 + [ $1 ] }
						.single()

					expect(result.isSuccess()).to(beTruthy())
					expect(result.value()).to(equal([ 1, 2 ]))
				}

				it("should yield the first two values received then complete") {
					var values: [Int] = []
					var completed = false

					bufferSignal.start(next: { value in
						values.append(value)
					}, completed: {
						completed = true
					})

					expect(values).to(equal([]))
					expect(completed).to(beFalsy())

					sink.put(1)
					expect(values).to(equal([ 1 ]))
					expect(completed).to(beFalsy())

					sink.put(2)
					expect(values).to(equal([ 1, 2 ]))
					expect(completed).to(beTruthy())
				}

				it("should yield a previous value then forward a new one") {
					sink.put(1)

					var values: [Int] = []
					var completed = false

					bufferSignal.start(next: { value in
						values.append(value)
					}, completed: {
						completed = true
					})

					expect(values).to(equal([ 1 ]))
					expect(completed).to(beFalsy())

					sink.put(2)
					expect(values).to(equal([ 1, 2 ]))
					expect(completed).to(beTruthy())
				}
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
