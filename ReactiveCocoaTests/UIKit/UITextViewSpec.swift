import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble

class UITextViewSpec: QuickSpec {
	override func spec() {
			var textView: UITextView!
			weak var _textView: UITextView?

			beforeEach {
				autoreleasepool {
					textView = UITextView(frame: .zero)
					_textView = textView
				}
			}

			afterEach {
				autoreleasepool {
					textView = nil
				}
				expect(_textView).toEventually(beNil())
			}

			it("should accept changes from bindings to its attributed text value") {
				let firstChange = NSAttributedString(string: "first")
				let secondChange = NSAttributedString(string: "second")
				
				textView.attributedText = NSAttributedString(string: "")
				
				let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
				textView.reactive.attributedText <~ SignalProducer(signal: pipeSignal)
				
				observer.send(value: firstChange)
				expect(textView.attributedText) == firstChange
				
				observer.send(value: secondChange)
				expect(textView.attributedText) == secondChange
			}

			it("should emit user initiated changes to its text value when the editing ends") {
				textView.text = "Test"

				var latestValue: String?
				textView.reactive.textValues.observeValues { text in
				latestValue = text
				}

				NotificationCenter.default.post(name: .UITextViewTextDidEndEditing,
				object: textView)
				expect(latestValue) == textView.text
			}

			it("should emit user initiated changes to its text value continuously") {
				textView.text = "Test"

				var latestValue: String?
					textView.reactive.continuousTextValues.observeValues { text in
						latestValue = text
				}

				NotificationCenter.default.post(name: .UITextViewTextDidChange,
				object: textView)
				expect(latestValue) == textView.text
		}
	}
}
