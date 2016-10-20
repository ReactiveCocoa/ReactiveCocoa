import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UIControlSpec: QuickSpec {
	override func spec() {
		var control: UIControl!
		weak var _control: UIControl?

		beforeEach {
			control = UIControl(frame: .zero)
			_control = control
		}
		afterEach {
			control = nil
			expect(_control).to(beNil())
		}

		it("should accept changes from bindings to its enabling state") {
			control.isEnabled = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			control.reactive.isEnabled <~ SignalProducer(signal: pipeSignal)

			observer.send(value: true)
			expect(control.isEnabled) == true

			observer.send(value: false)
			expect(control.isEnabled) == false
		}

		it("should accept changes from bindings to its selecting state") {
			control.isSelected = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			control.reactive.isSelected <~ SignalProducer(signal: pipeSignal)

			observer.send(value: true)
			expect(control.isSelected) == true

			observer.send(value: false)
			expect(control.isSelected) == false
		}

		it("should accept changes from bindings to its highlighting state") {
			control.isHighlighted = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			control.reactive.isHighlighted <~ SignalProducer(signal: pipeSignal)

			observer.send(value: true)
			expect(control.isHighlighted) == true

			observer.send(value: false)
			expect(control.isHighlighted) == false
		}

		it("should accept changes from mutliple bindings to its states") {
			control.isSelected = false
			control.isEnabled = false

			let (pipeSignalSelected, observerSelected) = Signal<Bool, NoError>.pipe()
			let (pipeSignalEnabled, observerEnabled) = Signal<Bool, NoError>.pipe()
			control.reactive.isSelected <~ SignalProducer(signal: pipeSignalSelected)
			control.reactive.isEnabled <~ SignalProducer(signal: pipeSignalEnabled)

			observerSelected.send(value: true)
			observerEnabled.send(value: true)
			expect(control.isEnabled) == true
			expect(control.isSelected) == true

			observerSelected.send(value: false)
			expect(control.isEnabled) == true
			expect(control.isSelected) == false

			observerEnabled.send(value: false)
			expect(control.isEnabled) == false
			expect(control.isSelected) == false
		}
	}
}
