import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UILabelSpec: QuickSpec {
	override func spec() {
		var label: UILabel!
		weak var _label: UILabel?

		beforeEach {
			label = UILabel(frame: .zero)
			_label = label
		}

		afterEach {
			label = nil
			expect(_label).to(beNil())
		}

		it("should accept changes from bindings to its text value") {
			let firstChange = "first"
			let secondChange = "second"

			label.text = ""

			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			label.reactive.text <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(label.text) == firstChange

			observer.send(value: secondChange)
			expect(label.text) == secondChange

			observer.send(value: nil)
			expect(label.text).to(beNil())
		}

		it("should accept changes from bindings to its attributed text value") {
			let firstChange = NSAttributedString(string: "first")
			let secondChange = NSAttributedString(string: "second")

			label.attributedText = NSAttributedString(string: "")

			let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
			label.reactive.attributedText <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(label.attributedText) == firstChange

			observer.send(value: secondChange)
			expect(label.attributedText) == secondChange
		}

		it("should accept changes from bindings to its text color value") {
			let firstChange = UIColor.red
			let secondChange = UIColor.black

			let label = UILabel(frame: .zero)

			let (pipeSignal, observer) = Signal<UIColor, NoError>.pipe()
			label.textColor = UIColor.black
			label.reactive.textColor <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(label.textColor) == firstChange

			observer.send(value: secondChange)
			expect(label.textColor) == secondChange
		}
	}
}
