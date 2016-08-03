//
//  SchedulerSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import Nimble
import Quick
@testable
import ReactiveCocoa

class SchedulerSpec: QuickSpec {
	override func spec() {
		describe("ImmediateScheduler") {
			it("should run enqueued actions immediately") {
				var didRun = false
				ImmediateScheduler().schedule {
					didRun = true
				}

				expect(didRun) == true
			}
		}

		describe("UIScheduler") {
			func dispatchSyncInBackground(_ action: () -> Void) {
				let group = DispatchGroup()

				DispatchQueue.global().async(group: group, execute: action)
				group.wait()
			}

			it("should run actions immediately when on the main thread") {
				let scheduler = UIScheduler()
				var values: [Int] = []
				expect(Thread.isMainThread) == true

				scheduler.schedule {
					values.append(0)
				}

				expect(values) == [ 0 ]

				scheduler.schedule {
					values.append(1)
				}

				scheduler.schedule {
					values.append(2)
				}

				expect(values) == [ 0, 1, 2 ]
			}

			it("should enqueue actions scheduled from the background") {
				let scheduler = UIScheduler()
				var values: [Int] = []

				dispatchSyncInBackground {
					scheduler.schedule {
						expect(Thread.isMainThread) == true
						values.append(0)
					}

					return
				}

				expect(values) == []
				expect(values).toEventually(equal([ 0 ]))

				dispatchSyncInBackground {
					scheduler.schedule {
						expect(Thread.isMainThread) == true
						values.append(1)
					}

					scheduler.schedule {
						expect(Thread.isMainThread) == true
						values.append(2)
					}

					return
				}

				expect(values) == [ 0 ]
				expect(values).toEventually(equal([ 0, 1, 2 ]))
			}

			it("should run actions enqueued from the main thread after those from the background") {
				let scheduler = UIScheduler()
				var values: [Int] = []

				dispatchSyncInBackground {
					scheduler.schedule {
						expect(Thread.isMainThread) == true
						values.append(0)
					}

					return
				}

				scheduler.schedule {
					expect(Thread.isMainThread) == true
					values.append(1)
				}

				scheduler.schedule {
					expect(Thread.isMainThread) == true
					values.append(2)
				}

				expect(values) == []
				expect(values).toEventually(equal([ 0, 1, 2 ]))
			}
		}

		describe("QueueScheduler") {
			it("should run enqueued actions on a global queue") {
				var didRun = false

				let scheduler: QueueScheduler
				if #available(OSX 10.10, *) {
					scheduler = QueueScheduler(qos: .default, name: "\(#file):\(#line)")
				} else {
					scheduler = QueueScheduler(queue: DispatchQueue(label: "\(#file):\(#line)", attributes: [.serial]))
				}

				scheduler.schedule {
					didRun = true
					expect(Thread.isMainThread) == false
				}

				expect{didRun}.toEventually(beTruthy())
			}

			describe("on a given queue") {
				var scheduler: QueueScheduler!

				beforeEach {
					if #available(OSX 10.10, *) {
						scheduler = QueueScheduler(qos: .default, name: "\(#file):\(#line)")
					} else {
						scheduler = QueueScheduler(queue: DispatchQueue(label: "\(#file):\(#line)", attributes: [.serial]))
					}
					scheduler.queue.suspend()
				}

				it("should run enqueued actions serially on the given queue") {
					var value = 0

					for _ in 0..<5 {
						scheduler.schedule {
							expect(Thread.isMainThread) == false
							value += 1
						}
					}

					expect(value) == 0

					scheduler.queue.resume()
					expect{value}.toEventually(equal(5))
				}

				it("should run enqueued actions after a given date") {
					var didRun = false
					scheduler.schedule(after: Date()) {
						didRun = true
						expect(Thread.isMainThread) == false
					}

					expect(didRun) == false

					scheduler.queue.resume()
					expect{didRun}.toEventually(beTruthy())
				}

				it("should repeatedly run actions after a given date") {
					let disposable = SerialDisposable()

					var count = 0
					let timesToRun = 3

					disposable.innerDisposable = scheduler.schedule(after: Date(), interval: 0.01, leeway: 0) {
						expect(Thread.isMainThread) == false

						count += 1

						if count == timesToRun {
							disposable.dispose()
						}
					}

					expect(count) == 0

					scheduler.queue.resume()
					expect{count}.toEventually(equal(timesToRun))
				}
			}
		}

		describe("TestScheduler") {
			var scheduler: TestScheduler!
			var startDate: Date!

			// How much dates are allowed to differ when they should be "equal."
			let dateComparisonDelta = 0.00001

			beforeEach {
				startDate = Date()

				scheduler = TestScheduler(startDate: startDate)
				expect(scheduler.currentDate) == startDate
			}

			it("should run immediately enqueued actions upon advancement") {
				var string = ""

				scheduler.schedule {
					string += "foo"
					expect(Thread.isMainThread) == true
				}

				scheduler.schedule {
					string += "bar"
					expect(Thread.isMainThread) == true
				}

				expect(string) == ""

				scheduler.advance()
				expect(scheduler.currentDate).to(beCloseTo(startDate))

				expect(string) == "foobar"
			}

			it("should run actions when advanced past the target date") {
				var string = ""

				scheduler.schedule(after: 15) { [weak scheduler] in
					string += "bar"
					expect(Thread.isMainThread) == true
					expect(scheduler?.currentDate).to(beCloseTo(startDate.addingTimeInterval(15), within: dateComparisonDelta))
				}

				scheduler.schedule(after: 5) { [weak scheduler] in
					string += "foo"
					expect(Thread.isMainThread) == true
					expect(scheduler?.currentDate).to(beCloseTo(startDate.addingTimeInterval(5), within: dateComparisonDelta))
				}

				expect(string) == ""

				scheduler.advance(by: 10)
				expect(scheduler.currentDate).to(beCloseTo(startDate.addingTimeInterval(10), within: TimeInterval(dateComparisonDelta)))
				expect(string) == "foo"

				scheduler.advance(by: 10)
				expect(scheduler.currentDate).to(beCloseTo(startDate.addingTimeInterval(20), within: dateComparisonDelta))
				expect(string) == "foobar"
			}

			it("should run all remaining actions in order") {
				var string = ""

				scheduler.schedule(after: 15) {
					string += "bar"
					expect(Thread.isMainThread) == true
				}

				scheduler.schedule(after: 5) {
					string += "foo"
					expect(Thread.isMainThread) == true
				}

				scheduler.schedule {
					string += "fuzzbuzz"
					expect(Thread.isMainThread) == true
				}

				expect(string) == ""

				scheduler.run()
				expect(scheduler.currentDate) == NSDate.distantFuture
				expect(string) == "fuzzbuzzfoobar"
			}
		}
	}
}
