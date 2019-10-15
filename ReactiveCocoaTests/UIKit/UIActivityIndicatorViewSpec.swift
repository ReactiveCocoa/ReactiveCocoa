#if canImport(UIKit)
import UIKit
import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa

class UIActivityIndicatorSpec: QuickSpec {
	override func spec() {
		var activityIndicatorView: UIActivityIndicatorView!
		weak var _activityIndicatorView: UIActivityIndicatorView?

		beforeEach {
			activityIndicatorView = UIActivityIndicatorView(frame: .zero)
			_activityIndicatorView = activityIndicatorView
		}

		afterEach {
			activityIndicatorView = nil
			expect(_activityIndicatorView).to(beNil())
		}

		it("should accept changes from bindings to its animating state") {
			let (pipeSignal, observer) = Signal<Bool, Never>.pipe()
			activityIndicatorView.reactive.isAnimating <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(activityIndicatorView.isAnimating) == true
			
			observer.send(value: false)
			expect(activityIndicatorView.isAnimating) == false
		}
	}
}
#endif
