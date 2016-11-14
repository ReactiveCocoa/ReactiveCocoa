import Quick
import Nimble
import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import UIKit

class UIStepperSpec: QuickSpec {
	override func spec() {
		var stepper: UIStepper!
		weak var _stepper: UIStepper?

		beforeEach {
			stepper = UIStepper()
			_stepper = stepper
		}

		afterEach {
			stepper = nil
			expect(_stepper).to(beNil())
		}

		it("should accept changes from bindings to its value") {
			expect(stepper.value) == 0.0

			let (pipeSignal, observer) = Signal<Double, NoError>.pipe()

			stepper.reactive.value <~ pipeSignal

			observer.send(value: 0.5)
			expect(stepper.value) ≈ 0.5
		}

		it("should accept changes from bindings to its minimum value") {
			expect(stepper.minimumValue) == 0.0

			let (pipeSignal, observer) = Signal<Double, NoError>.pipe()

			stepper.reactive.minimumValue <~ pipeSignal

			observer.send(value: 0.3)
			expect(stepper.minimumValue) ≈ 0.3
		}

		it("should accept changes from bindings to its maximum value") {
			expect(stepper.maximumValue) == 100.0

			let (pipeSignal, observer) = Signal<Double, NoError>.pipe()

			stepper.reactive.maximumValue <~ pipeSignal

			observer.send(value: 33.0)
			expect(stepper.maximumValue) ≈ 33.0
		}

		it("should emit user's changes for its value") {
			stepper.value = 0.25

			var updatedValue: Double?
			stepper.reactive.values.observeValues { value in
				updatedValue = value
			}

			expect(updatedValue).to(beNil())
			stepper.sendActions(for: .valueChanged)
			expect(updatedValue) ≈ 0.25
		}
	}
}
