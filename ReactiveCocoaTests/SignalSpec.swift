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
				signal.observe { observedValues.append($0) }
				expect(observedValues).to(equal([ 0 ]))

				dispatch_resume(queue)
				dispatch_sync(queue) {}
				expect(observedValues).to(equal([ 0, 1, 2, 3 ]))
			}

			it("should instantiate a pipe") {
				let (signal, sink) = Signal.pipeWithInitialValue(0)
				expect(signal.current).to(equal(0))

				var observedValues: [Int] = []
				signal.observe { observedValues.append($0) }
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

				scheduler.advanceToDate(signal.current)
				expect(observedDates).to(equal(1))

				scheduler.advanceByInterval(2.5)
				expect(observedDates).to(equal(3))

				scheduler.advanceByInterval(1)
				expect(observedDates).to(equal(4))
			}
		}
	}
}
