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

		it("should execute the `pressed` action upon receiving a click") {
			button.isEnabled = true

			let pressed = MutableProperty(false)
			let action = Action<(), Bool, NoError> { _ in
				SignalProducer(value: true)
			}

			pressed <~ SignalProducer(action.values)
			button.reactive.pressed = CocoaAction(action)
			expect(pressed.value) == false

			button.performClick(nil)
			expect(pressed.value) == true
		}
	}
}

