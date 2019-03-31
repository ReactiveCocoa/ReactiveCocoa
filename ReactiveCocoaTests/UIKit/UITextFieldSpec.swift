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

			// FIXME: iOS 11.0 SDK beta 1
			// expect(_textField).toEventually(beNil())
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

		it("should emit user initiated changes to its text value when the editing ends as a reuslt of the return key being pressed") {
			textField.text = "Test"

			var latestValue: String?
			textField.reactive.textValues.observeValues { text in
				latestValue = text
			}

			textField.sendActions(for: .editingDidEndOnExit)
			expect(latestValue) == textField.text
		}

		it("should emit user initiated changes to its text value continuously") {
			var latestValue: String?
			textField.reactive.continuousTextValues.observeValues { text in
				latestValue = text
			}

			for event in UIControl.Event.editingEvents {
				textField.text = "Test \(event)"

				textField.sendActions(for: event)
				expect(latestValue) == textField.text
			}
		}
		
		it("should accept changes from bindings to its attributed text value") {
			let firstChange = NSAttributedString(string: "first")
			let secondChange = NSAttributedString(string: "second")
			
			textField.attributedText = NSAttributedString(string: "")
			
			let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
			textField.reactive.attributedText <~ SignalProducer(pipeSignal)
			
			observer.send(value: firstChange)
			expect(textField.attributedText?.string) == firstChange.string
			
			observer.send(value: secondChange)
			expect(textField.attributedText?.string) == secondChange.string
		}
		
		it("should emit user initiated changes to its attributed text value when the editing ends") {
			textField.attributedText = NSAttributedString(string: "Test")
			
			var latestValue: NSAttributedString?
			textField.reactive.attributedTextValues.observeValues { attributedText in
				latestValue = attributedText
			}
			
			textField.sendActions(for: .editingDidEnd)
			expect(latestValue) == textField.attributedText
		}

		it("should emit user initiated changes to its attributed text value when the editing ends as a result of the return key being pressed") {
			textField.attributedText = NSAttributedString(string: "Test")

			var latestValue: NSAttributedString?
			textField.reactive.attributedTextValues.observeValues { attributedText in
				latestValue = attributedText
			}

			textField.sendActions(for: .editingDidEndOnExit)
			expect(latestValue) == textField.attributedText
		}

		it("should emit user initiated changes to its attributed text value continuously") {
			var latestValue: NSAttributedString?
			textField.reactive.continuousAttributedTextValues.observeValues { attributedText in
				latestValue = attributedText
			}

			for event in UIControl.Event.editingEvents {
				textField.attributedText = NSAttributedString(string: "Test \(event)")

				textField.sendActions(for: event)
				expect(latestValue?.string) == textField.attributedText?.string
			}
		}

		it("should accept changes from bindings to its placeholder attribute") {
			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			textField.reactive.placeholder <~ pipeSignal

			observer.send(value: "A placeholder")
			expect(textField.placeholder).to(equal("A placeholder"))

			observer.send(value: nil)
			expect(textField.placeholder).to(beNil())

			observer.send(value: "Another placeholder")
			expect(textField.placeholder).to(equal("Another placeholder"))
		}

		it("should accept changes from bindings to its secureTextEntry attribute") {
			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			textField.reactive.isSecureTextEntry <~ pipeSignal

			observer.send(value: true)
			expect(textField.isSecureTextEntry) == true

			observer.send(value: false)
			expect(textField.isSecureTextEntry) == false
		}
		
		it("should accept changes from bindings to its textColor attribute") {
			let (pipeSignal, observer) = Signal<UIColor, NoError>.pipe()
			textField.reactive.textColor <~ pipeSignal
			
			observer.send(value: UIColor.red)
			expect(textField.textColor == UIColor.red) == true
			
			observer.send(value: UIColor.blue)
			expect(textField.textColor == UIColor.red) == false
		}

		it("should not deadlock when the text field is asked to resign first responder by any of its observers") {
			UIView.setAnimationsEnabled(false)
			defer { UIView.setAnimationsEnabled(true) }

			autoreleasepool {
				let window = UIWindow(frame: .zero)
				window.addSubview(textField)

				defer {
					textField.removeFromSuperview()
					expect(textField.superview).to(beNil())
				}

				expect(textField.becomeFirstResponder()) == true
				expect(textField.isFirstResponder) == true

				var values: [String] = []

				textField.reactive.continuousTextValues.observeValues { text in
					values.append(text)

					if text == "2" {
						textField.resignFirstResponder()
						textField.text = "3"
					}
				}
				expect(values) == []

				textField.text = "1"
				textField.sendActions(for: .editingChanged)
				expect(values) == ["1"]

				textField.text = "2"
				textField.sendActions(for: .editingChanged)
				expect(textField.isFirstResponder) == false
				expect(values) == ["1", "2", "2"]
			}
		}
	}
}

extension UIControl.Event {
	fileprivate static var editingEvents: [UIControl.Event] {
		return [.allEditingEvents, .editingDidBegin, .editingChanged, .editingDidEndOnExit, .editingDidEnd]
	}
}
