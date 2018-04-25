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
	}
}
