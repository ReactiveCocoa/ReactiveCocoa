//
//  FoundationExtensionsSpec.swift
//  ReactiveCocoa
//
//  Created by Neil Pankey on 5/22/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

private final class FooClass {}

class FoundationExtensionsSpec: QuickSpec {
	override func spec() {
		describe("NSNotificationCenter.rac_notifications") {
			let center = NSNotificationCenter.defaultCenter()

			it("should send notifications on the producer") {
				let producer = center.rac_notifications("rac_notifications_test")

				var notif: NSNotification? = nil
				let disposable = producer.startWithNext { notif = $0 }

				center.postNotificationName("some_other_notification", object: nil)
				expect(notif).to(beNil())

				center.postNotificationName("rac_notifications_test", object: nil)
				expect(notif?.name) == "rac_notifications_test"

				notif = nil
				disposable.dispose()

				center.postNotificationName("rac_notifications_test", object: nil)
				expect(notif).to(beNil())
			}

			it("should send Interrupted when the observed object is freed") {
				var observedObject: AnyObject? = FooClass()
				let producer = center.rac_notifications(object: observedObject)
				observedObject = nil

				var interrupted = false
				let disposable = producer.startWithInterrupted {
					interrupted = true
				}
				expect(interrupted) == true

				disposable.dispose()
			}

			context("observing NSObject-derived objects") {
				it("should send Completed when the observed object is freed before resulting producer is started") {
					var observedObject: AnyObject? = NSObject()
					let producer = center.rac_notifications(object: observedObject)
					observedObject = nil

					var completed = false
					let disposable = producer.startWithCompleted {
						completed = true
					}
					expect(completed) == true

					disposable.dispose()
				}

				it("should send Completed when the observed object is freed after resulting producer is started") {
					var observedObject: AnyObject? = NSObject()
					let producer = center.rac_notifications(object: observedObject)

					var completed = false
					let disposable = producer.startWithCompleted {
						completed = true
					}

					observedObject = nil
					expect(completed) == true
					
					disposable.dispose()
				}
			}
		}
	}
}
