import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import AppKit
import enum Result.NoError

class NSButtonSpec: QuickSpec {
	override func spec() {
		var button: NSButton!
		weak var _button: NSButton?

		beforeEach {
			button = NSButton(frame: .zero)
			_button = button
		}

		afterEach {
			button = nil
			expect(_button).to(beNil())
		}

		it("should accept changes from bindings to its enabling state") {
			button.isEnabled = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			button.reactive.isEnabled <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(button.isEnabled) == true

			observer.send(value: false)
			expect(button.isEnabled) == false
		}

		it("should execute the `pressed` action upon receiving a click") {
			button.isEnabled = true

			let pressed = MutableProperty(false)

			let (executionSignal, observer) = Signal<Bool, NoError>.pipe()
			let action = Action<(), Bool, NoError> { _ in
				SignalProducer(executionSignal)
			}

			pressed <~ SignalProducer(action.values)
			button.reactive.pressed = CocoaAction(action)
			expect(pressed.value) == false

			button.performClick(nil)
			expect(button.isEnabled) == false

			observer.send(value: true)
			observer.sendCompleted()

			expect(button.isEnabled) == true
			expect(pressed.value) == true
		}
	}
}

