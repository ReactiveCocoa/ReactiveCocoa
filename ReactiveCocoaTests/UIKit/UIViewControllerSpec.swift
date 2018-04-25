import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UIViewControllerSpec: QuickSpec {
	override func spec() {
		var viewController: UIViewController!
		weak var _viewController: UIViewController?

		beforeEach {
			viewController = UIViewController()
			_viewController = viewController
		}

		afterEach {
			viewController = nil
			expect(_viewController).to(beNil())
		}

		it("should accept changes from bindings to its title value") {
			let firstChange = "first"
			let secondChange = "second"

			viewController.title = ""

			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			viewController.reactive.title <~ pipeSignal

			observer.send(value: firstChange)
			expect(viewController.title) == firstChange

			observer.send(value: secondChange)
			expect(viewController.title) == secondChange

			observer.send(value: nil)
			expect(viewController.title).to(beNil())
		}

		it("should send a `value` event when `viewWillAppear` is invoked") {
			var isInvoked = false
			viewController.reactive.viewWillAppear.observeValues {
				isInvoked = true
			}

			expect(isInvoked) == false

			viewController.viewWillAppear(false)
			expect(isInvoked) == true
		}

		it("should send a `value` event when `viewDidAppear` is invoked") {
			var isInvoked = false
			viewController.reactive.viewDidAppear.observeValues {
				isInvoked = true
			}

			expect(isInvoked) == false

			viewController.viewDidAppear(false)
			expect(isInvoked) == true
		}

		it("should send a `value` event when `viewWillDisappear` is invoked") {
			var isInvoked = false
			viewController.reactive.viewWillDisappear.observeValues {
				isInvoked = true
			}

			expect(isInvoked) == false

			viewController.viewWillDisappear(false)
			expect(isInvoked) == true
		}

		it("should send a `value` event when `viewDidDisappear` is invoked") {
			var isInvoked = false
			viewController.reactive.viewDidDisappear.observeValues {
				isInvoked = true
			}

			expect(isInvoked) == false

			viewController.viewDidDisappear(false)
			expect(isInvoked) == true
		}

		it("should send a `value` event when `viewWillLayoutSubviews` is invoked") {
			var isInvoked = false
			viewController.reactive.viewWillLayoutSubviews.observeValues {
				isInvoked = true
			}

			expect(isInvoked) == false

			viewController.viewWillLayoutSubviews()
			expect(isInvoked) == true
		}

		it("should send a `value` event when `viewDidLayoutSubviews` is invoked") {
			var isInvoked = false
			viewController.reactive.viewDidLayoutSubviews.observeValues {
				isInvoked = true
			}

			expect(isInvoked) == false

			viewController.viewDidLayoutSubviews()
			expect(isInvoked) == true
		}
	}
}
