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
			textView = UITextView(frame: .zero)
			_textView = textView
		}

		afterEach {
			textView = nil

			// Disabled due to an issue of the iOS SDK.
			// Please refer to https://github.com/ReactiveCocoa/ReactiveCocoa/issues/3251
			// for more information.
			//
			// expect(_textView).to(beNil())
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
			let textView = UITextView(frame: .zero)
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
