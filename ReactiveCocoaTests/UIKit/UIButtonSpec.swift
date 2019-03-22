import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import UIKit
import enum Result.NoError

class UIButtonSpec: QuickSpec {
	override func spec() {
		var button: UIButton!
		weak var _button: UIButton?

		beforeEach {
			button = UIButton(frame: .zero)
			_button = button
		}

		afterEach {
			button = nil
			expect(_button).to(beNil())
		}

		it("should accept changes from bindings to its titles under different states") {
			let firstTitle = "First title"
			let secondTitle = "Second title"

			let (pipeSignal, observer) = Signal<String, NoError>.pipe()
			button.reactive.title <~ SignalProducer(pipeSignal)
			button.setTitle("", for: .selected)
			button.setTitle("", for: .highlighted)

			observer.send(value: firstTitle)
			expect(button.title(for: UIControl.State())) == firstTitle
			expect(button.title(for: .highlighted)) == ""
			expect(button.title(for: .selected)) == ""

			observer.send(value: secondTitle)
			expect(button.title(for: UIControl.State())) == secondTitle
			expect(button.title(for: .highlighted)) == ""
			expect(button.title(for: .selected)) == ""
		}

		let pressedTest: (UIButton, UIControl.Event) -> Void = { button, event in
			button.isEnabled = true
			button.isUserInteractionEnabled = true

			let pressed = MutableProperty(false)
			let action = Action<(), Bool, NoError> { _ in
				SignalProducer(value: true)
			}

			pressed <~ SignalProducer(action.values)

			button.reactive.pressed = CocoaAction(action)
			expect(pressed.value) == false

			button.sendActions(for: event)

			expect(pressed.value) == true
		}

		if #available(iOS 9.0, tvOS 9.0, *) {
			it("should execute the `pressed` action upon receiving a `primaryActionTriggered` action message.") {
				pressedTest(button, .primaryActionTriggered)
			}
		} else {
			it("should execute the `pressed` action upon receiving a `touchUpInside` action message.") {
				pressedTest(button, .touchUpInside)
			}
		}
	}
}

