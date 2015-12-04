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

				expect(didRun).to(beTruthy())
			}
		}

		describe("UIScheduler") {
			func dispatchSyncInBackground(action: () -> ()) {
				let group = dispatch_group_create()
				dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), action)
				dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
			}

			it("should run actions immediately when on the main thread") {
				let scheduler = UIScheduler()
				var values: [Int] = []
				expect(NSThread.isMainThread()).to(beTruthy())

				scheduler.schedule {
					values.append(0)
				}

				expect(values).to(equal([ 0 ]))

				scheduler.schedule {
					values.append(1)
				}

				scheduler.schedule {
					values.append(2)
				}

				expect(values).to(equal([ 0, 1, 2 ]))
			}

			it("should enqueue actions scheduled from the background") {
				let scheduler = UIScheduler()
				var values: [Int] = []

				dispatchSyncInBackground {
					scheduler.schedule {
						expect(NSThread.isMainThread()).to(beTruthy())
						values.append(0)
					}

					return
				}

				expect(values).to(equal([]))
				expect(values).toEventually(equal([ 0 ]))

				dispatchSyncInBackground {
					scheduler.schedule {
						expect(NSThread.isMainThread()).to(beTruthy())
						values.append(1)
					}

					scheduler.schedule {
						expect(NSThread.isMainThread()).to(beTruthy())
						values.append(2)
					}

					return
				}

				expect(values).to(equal([ 0 ]))
				expect(values).toEventually(equal([ 0, 1, 2 ]))
			}

			it("should run actions enqueued from the main thread after those from the background") {
				let scheduler = UIScheduler()
				var values: [Int] = []

				dispatchSyncInBackground {
					scheduler.schedule {
						expect(NSThread.isMainThread()).to(beTruthy())
						values.append(0)
					}

					return
				}

				scheduler.schedule {
					expect(NSThread.isMainThread()).to(beTruthy())
					values.append(1)
				}

				scheduler.schedule {
					expect(NSThread.isMainThread()).to(beTruthy())
					values.append(2)
				}

				expect(values).to(equal([]))
				expect(values).toEventually(equal([ 0, 1, 2 ]))
			}
		}

		describe("QueueScheduler") {
			it("should run enqueued actions on a global queue") {
				var didRun = false
				let scheduler: QueueScheduler
				if #available(OSX 10.10, *) {
					scheduler = QueueScheduler(qos: QOS_CLASS_DEFAULT)
				} else {
					scheduler = QueueScheduler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
				}
				scheduler.schedule {
					didRun = true
					expect(NSThread.isMainThread()).to(beFalsy())
				}

				expect{didRun}.toEventually(beTruthy())
			}

			describe("on a given queue") {
				var scheduler: QueueScheduler!

				beforeEach {
					if #available(OSX 10.10, *) {
						scheduler = QueueScheduler(qos: QOS_CLASS_DEFAULT)
					} else {
						scheduler = QueueScheduler(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
					}
					dispatch_suspend(scheduler.queue)
				}

				it("should run enqueued actions serially on the given queue") {
					var value = 0

					for _ in 0..<5 {
						scheduler.schedule {
							expect(NSThread.isMainThread()).to(beFalsy())
							value++
						}
					}

					expect(value).to(equal(0))

					dispatch_resume(scheduler.queue)
					expect{value}.toEventually(equal(5))
				}

				it("should run enqueued actions after a given date") {
					var didRun = false
					scheduler.scheduleAfter(NSDate()) {
						didRun = true
						expect(NSThread.isMainThread()).to(beFalsy())
					}

					expect(didRun).to(beFalsy())

					dispatch_resume(scheduler.queue)
					expect{didRun}.toEventually(beTruthy())
				}

				it("should repeatedly run actions after a given date") {
					let disposable = SerialDisposable()

					var count = 0
					let timesToRun = 3

					disposable.innerDisposable = scheduler.scheduleAfter(NSDate(), repeatingEvery: 0.01, withLeeway: 0) {
						expect(NSThread.isMainThread()).to(beFalsy())

						if ++count == timesToRun {
							disposable.dispose()
						}
					}

					expect(count).to(equal(0))

					dispatch_resume(scheduler.queue)
					expect{count}.toEventually(equal(timesToRun))
				}
			}
		}

		describe("TestScheduler") {
			var scheduler: TestScheduler!
			var startDate: NSDate!

			// How much dates are allowed to differ when they should be "equal."
			let dateComparisonDelta = 0.00001

			beforeEach {
				startDate = NSDate()

				scheduler = TestScheduler(startDate: startDate)
				expect(scheduler.currentDate).to(equal(startDate))
			}

			it("should run immediately enqueued actions upon advancement") {
				var string = ""

				scheduler.schedule {
					string += "foo"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				scheduler.schedule {
					string += "bar"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				expect(string).to(equal(""))

				scheduler.advance()
				expect(scheduler.currentDate).to(beCloseTo(startDate))

				expect(string).to(equal("foobar"))
			}

			it("should run actions when advanced past the target date") {
				var string = ""

				scheduler.scheduleAfter(15) {
					string += "bar"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				scheduler.scheduleAfter(5) {
					string += "foo"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				expect(string).to(equal(""))

				scheduler.advanceByInterval(10)
				expect(scheduler.currentDate).to(beCloseTo(startDate.dateByAddingTimeInterval(10), within: dateComparisonDelta))
				expect(string).to(equal("foo"))

				scheduler.advanceByInterval(10)
				expect(scheduler.currentDate).to(beCloseTo(startDate.dateByAddingTimeInterval(20), within: dateComparisonDelta))
				expect(string).to(equal("foobar"))
			}

			it("should run all remaining actions in order") {
				var string = ""

				scheduler.scheduleAfter(15) {
					string += "bar"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				scheduler.scheduleAfter(5) {
					string += "foo"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				scheduler.schedule {
					string += "fuzzbuzz"
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				expect(string).to(equal(""))

				scheduler.run()
				expect(scheduler.currentDate).to(equal(NSDate.distantFuture()))
				expect(string).to(equal("fuzzbuzzfoobar"))
			}
		}
	}
}
