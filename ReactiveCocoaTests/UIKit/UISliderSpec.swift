import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import UIKit

class UISliderSpec: QuickSpec {
    override func spec() {
		var slider: UISlider!
		weak var _slider: UISlider?

		beforeEach {
			slider = UISlider()
			_slider = slider
		}

		afterEach {
			slider = nil
			expect(_slider).to(beNil())
		}

		it("should accept changes from bindings to its value") {
			expect(slider.value) == 0.0

			let (pipeSignal, observer) = Signal<Float, NoError>.pipe()

			slider.reactive.value <~ pipeSignal

			observer.send(value: 0.5)
			expect(slider.value) ≈ 0.5
		}

		it("should accept changes from bindings to its minimum value") {
			expect(slider.minimumValue) == 0.0

			let (pipeSignal, observer) = Signal<Float, NoError>.pipe()

			slider.reactive.minimumValue <~ pipeSignal

			observer.send(value: 0.3)
			expect(slider.minimumValue) ≈ 0.3
		}

		it("should accept changes from bindings to its maximum value") {
			expect(slider.maximumValue) == 1.0

			let (pipeSignal, observer) = Signal<Float, NoError>.pipe()

			slider.reactive.maximumValue <~ pipeSignal

			observer.send(value: 0.7)
			expect(slider.maximumValue) ≈ 0.7
		}

		it("should emit user's changes for its value") {
			slider.value = 0.25

			var updatedValue: Float?
			slider.reactive.values.observeValues { value in
				updatedValue = value
			}

			expect(updatedValue).to(beNil())
			slider.sendActions(for: .valueChanged)
			expect(updatedValue) ≈ 0.25
		}
    }
}
