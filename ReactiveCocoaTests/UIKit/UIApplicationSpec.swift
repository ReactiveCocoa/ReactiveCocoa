import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UIApplicationSpec: QuickSpec {
	override func spec() {
		it("should accept changes from bindings to its applicationIconBadgeNumber value") {
			let application = UIApplication.shared

			application.applicationIconBadgeNumber = 0

			let (pipeSignal, observer) = Signal<Int, NoError>.pipe()
			application.reactive.applicationIconBadgeNumber <~ pipeSignal

			observer.send(value: 1)
			expect(application.applicationIconBadgeNumber) == 1

			observer.send(value: 1337)
			expect(application.applicationIconBadgeNumber) == 1337
		}
	}
}
