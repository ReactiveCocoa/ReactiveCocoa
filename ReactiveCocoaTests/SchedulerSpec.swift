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

		describe("MainScheduler") {
			it("should run enqueued actions on the main thread") {
				var didRun = false
				MainScheduler().schedule {
					didRun = true
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				expect(didRun).to(beFalsy())
				expect{didRun}.toEventually(beTruthy())
			}

			it("should run enqueued actions after a given date") {
				var didRun = false
				MainScheduler().scheduleAfter(NSDate()) {
					didRun = true
					expect(NSThread.isMainThread()).to(beTruthy())
				}

				expect(didRun).to(beFalsy())
				expect{didRun}.toEventually(beTruthy())
			}

			it("should repeatedly run actions after a given date") {
				let disposable = SerialDisposable()

				var count = 0
				let timesToRun = 3

				disposable.innerDisposable = MainScheduler().scheduleAfter(NSDate(), repeatingEvery: 0.01, withLeeway: 0) {
					expect(NSThread.isMainThread()).to(beTruthy())

					if ++count == timesToRun {
						disposable.dispose()
					}
				}

				expect(count).to(equal(0))
				expect{count}.toEventually(equal(timesToRun))
			}
		}

		describe("QueueScheduler") {
			it("should run enqueued actions on a global queue") {
				var didRun = false
				QueueScheduler().schedule {
					didRun = true
					expect(NSThread.isMainThread()).to(beFalsy())
				}

				expect{didRun}.toEventually(beTruthy())
			}

			describe("on a given queue") {
				var queue: dispatch_queue_t!
				var scheduler: QueueScheduler!

				beforeEach {
					queue = dispatch_queue_create("", DISPATCH_QUEUE_CONCURRENT)
					dispatch_suspend(queue)

					scheduler = QueueScheduler(queue)
				}

				it("should run enqueued actions serially on the given queue") {
					var value = 0

					for i in 0..<5 {
						scheduler.schedule {
							expect(NSThread.isMainThread()).to(beFalsy())
							value = value + 1
						}
					}

					expect(value).to(equal(0))

					dispatch_resume(queue)
					expect{value}.toEventually(equal(5))
				}

				it("should run enqueued actions after a given date") {
					var didRun = false
					scheduler.scheduleAfter(NSDate()) {
						didRun = true
						expect(NSThread.isMainThread()).to(beFalsy())
					}

					expect(didRun).to(beFalsy())

					dispatch_resume(queue)
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

					dispatch_resume(queue)
					expect{count}.toEventually(equal(timesToRun))
				}
			}
		}

		describe("TestScheduler") {
		}
	}
}
