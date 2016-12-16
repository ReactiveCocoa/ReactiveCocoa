import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UIViewSpec: QuickSpec {
	override func spec() {
		var view: UIView!
		weak var _view: UIView?

		beforeEach {
			view = UIView(frame: .zero)
			_view = view
		}

		afterEach {
			view = nil
			expect(_view).to(beNil())
		}

		it("should accept changes from bindings to its hiding state") {
			view.isHidden = true

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			view.reactive.isHidden <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(view.isHidden) == true

			observer.send(value: false)
			expect(view.isHidden) == false
		}

		it("should accept changes from bindings to its alpha value") {
			view.alpha = 0.0

			let firstChange = CGFloat(0.5)
			let secondChange = CGFloat(0.7)

			let (pipeSignal, observer) = Signal<CGFloat, NoError>.pipe()
			view.reactive.alpha <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(view.alpha) ≈ firstChange

			observer.send(value: secondChange)
			expect(view.alpha) ≈ secondChange
		}

		it("should accept changes from bindings to its user interaction enabling state") {
			view.isUserInteractionEnabled = true

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			view.reactive.isUserInteractionEnabled <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(view.isUserInteractionEnabled) == true
			
			observer.send(value: false)
			expect(view.isUserInteractionEnabled) == false
		}

		it("should accept changes from bindings to its background color") {
			view.backgroundColor = .white

			let (pipeSignal, observer) = Signal<UIColor, NoError>.pipe()
			view.reactive.backgroundColor <~ SignalProducer(pipeSignal)

			observer.send(value: .yellow)
			expect(view.backgroundColor) == .yellow

			observer.send(value: .green)
			expect(view.backgroundColor) == .green

			observer.send(value: .red)
			expect(view.backgroundColor) == .red
		}
	}
}
