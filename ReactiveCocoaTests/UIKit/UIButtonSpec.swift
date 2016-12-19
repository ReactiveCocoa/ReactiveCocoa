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
			expect(button.title(for: UIControlState())) == firstTitle
			expect(button.title(for: .highlighted)) == ""
			expect(button.title(for: .selected)) == ""

			observer.send(value: secondTitle)
			expect(button.title(for: UIControlState())) == secondTitle
			expect(button.title(for: .highlighted)) == ""
			expect(button.title(for: .selected)) == ""
		}

		it("should execute the `pressed` action upon receiving a `touchUpInside` action message.") {
			button.isEnabled = true
			button.isUserInteractionEnabled = true

			let pressed = MutableProperty(false)
			let action = Action<(), Bool, NoError> { _ in
				SignalProducer(value: true)
			}

			pressed <~ SignalProducer(action.values)

			button.reactive.pressed = CocoaAction(action)
			expect(pressed.value) == false
			
			button.sendActions(for: .touchUpInside)
			expect(pressed.value) == true
		}
	}
}
