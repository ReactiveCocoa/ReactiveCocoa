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
