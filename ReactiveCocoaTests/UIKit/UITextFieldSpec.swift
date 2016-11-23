import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UITextFieldSpec: QuickSpec {
	override func spec() {
		var textField: UITextField!
		weak var _textField: UITextField?

		beforeEach {
			autoreleasepool {
				textField = UITextField(frame: .zero)
				_textField = textField
			}
		}

		afterEach {
			autoreleasepool {
				textField = nil
			}
			expect(_textField).to(beNil())
		}
		
		it("should accept changes from bindings to its attributed text value") {
			let firstChange = NSAttributedString(string: "first")
			let secondChange = NSAttributedString(string: "second")
			
			textField.attributedText = NSAttributedString(string: "")
			
			let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
			textField.reactive.attributedText <~ SignalProducer(signal: pipeSignal)
			
			observer.send(value: firstChange)
			expect(textField.attributedText) == firstChange
			
			observer.send(value: secondChange)
			expect(textField.attributedText) == secondChange
		}

		it("should emit user initiated changes to its text value when the editing ends") {
			textField.text = "Test"

			var latestValue: String?
			textField.reactive.textValues.observeValues { text in
				latestValue = text
			}

			textField.sendActions(for: .editingDidEnd)
			expect(latestValue) == textField.text
		}

		it("should emit user initiated changes to its text value continuously") {
			textField.text = "Test"

			var latestValue: String?
			textField.reactive.continuousTextValues.observeValues { text in
				latestValue = text
			}

			textField.sendActions(for: .editingChanged)
			expect(latestValue) == textField.text
		}
	}
}
