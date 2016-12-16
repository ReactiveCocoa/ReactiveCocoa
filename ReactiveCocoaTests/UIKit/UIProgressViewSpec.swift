import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UIProgressViewSpec: QuickSpec {
	override func spec() {
		var progressView: UIProgressView!
		weak var _progressView: UIProgressView?

		beforeEach {
			progressView = UIProgressView(frame: .zero)
			_progressView = progressView
		}

		afterEach {
			progressView = nil
			expect(_progressView).to(beNil())
		}

		it("should accept changes from bindings to its progress value") {
			let firstChange: Float = 0.5
			let secondChange: Float = 0.0

			progressView.progress = 1.0

			let (pipeSignal, observer) = Signal<Float, NoError>.pipe()
			progressView.reactive.progress <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(progressView.progress) ≈ firstChange

			observer.send(value: secondChange)
			expect(progressView.progress) ≈ secondChange
		}
	}
}
