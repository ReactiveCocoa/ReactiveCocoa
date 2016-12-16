import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UITextViewSpec: QuickSpec {
	override func spec() {
		var textView: UITextView!
		weak var _textView: UITextView?
		let attributes = [
			NSFontAttributeName: UIFont.systemFont(ofSize: 18),
			NSForegroundColorAttributeName: UIColor.red
		]
		
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

			NotificationCenter.default.post(name: .UITextViewTextDidEndEditing, object: textView)
			expect(latestValue) == textView.text
		}

		it("should emit user initiated changes to its text value continuously") {
			textView.text = "Test"

			var latestValue: String?
			textView.reactive.continuousTextValues.observeValues { text in
				latestValue = text
			}

			NotificationCenter.default.post(name: .UITextViewTextDidChange, object: textView)
			expect(latestValue) == textView.text
		}
		
		it("should accept changes from bindings to its attributed text value") {
			let firstChange = NSAttributedString(string: "first", attributes: attributes)
			let secondChange = NSAttributedString(string: "second", attributes: attributes)
			
			textView.attributedText = NSAttributedString(string: "")
			
			let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
			textView.reactive.attributedText <~ SignalProducer(pipeSignal)
			
			observer.send(value: firstChange)
			expect(textView.attributedText) == firstChange
			
			observer.send(value: secondChange)
			expect(textView.attributedText) == secondChange
		}
		
		it("should emit user initiated changes to its attributed text value when the editing ends") {
			textView.attributedText = NSAttributedString(string: "Test", attributes: attributes)
			
			var latestValue: NSAttributedString?
			textView.reactive.attributedTextValues.observeValues { attributedText in
				latestValue = attributedText
			}
			
			NotificationCenter.default.post(name: .UITextViewTextDidEndEditing, object: textView)
			expect(latestValue) == textView.attributedText
		}
		
		it("should emit user initiated changes to its attributed text value continuously") {
			textView.attributedText = NSAttributedString(string: "Test", attributes: attributes)
			
			var latestValue: NSAttributedString?
			textView.reactive.continuousAttributedTextValues.observeValues { attributedText in
				latestValue = attributedText
			}
			
			NotificationCenter.default.post(name: .UITextViewTextDidChange, object: textView)
			expect(latestValue) == textView.attributedText
		}
	}
}
