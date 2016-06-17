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

class FoundationExtensionsSpec: QuickSpec {
	override func spec() {
		describe("NSNotificationCenter.rac_notifications") {
			let center = NotificationCenter.default()

			it("should send notifications on the producer") {
				let producer = center.rac_notifications(name: "rac_notifications_test" as NSNotification.Name)

				var notif: NSNotification? = nil
				let disposable = producer.startWithNext { notif = $0 }

				center.post(name: "some_other_notification" as NSNotification.Name, object: nil)
				expect(notif).to(beNil())

				center.post(name: "rac_notifications_test" as NSNotification.Name, object: nil)
				expect(notif?.name) == "rac_notifications_test" as NSNotification.Name

				notif = nil
				disposable.dispose()

				center.post(name: "rac_notifications_test" as NSNotification.Name, object: nil)
				expect(notif).to(beNil())
			}

			it("should send Interrupted when the observed object is freed") {
				var observedObject: AnyObject? = NSObject()
				let producer = center.rac_notifications(name: nil, object: observedObject)
				observedObject = nil

				var interrupted = false
				let disposable = producer.startWithInterrupted {
					interrupted = true
				}
				expect(interrupted) == true

				disposable.dispose()
			}

		}
	}
}
