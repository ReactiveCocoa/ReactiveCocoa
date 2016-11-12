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
	}
}
