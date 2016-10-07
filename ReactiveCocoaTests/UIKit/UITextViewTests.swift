import ReactiveSwift
import ReactiveCocoa
import UIKit
import XCTest

class UITextViewTests: XCTestCase {
	func testTexts() {
		let expectation = self.expectation(description: "Expected `texts`'s value to equal to the textViews's text")
		defer { self.waitForExpectations(timeout: 2, handler: nil) }

		let textView = UITextView(frame: CGRect.zero)
		textView.text = "Test"

		textView.reactive.textValues.observeValues { text in
			XCTAssertEqual(text, textView.text)
			expectation.fulfill()
		}

		NotificationCenter.default.post(name: NSNotification.Name.UITextViewTextDidEndEditing, object: textView)
	}

	func testContinuousTexts() {
		let expectation = self.expectation(description: "Expected `continuousTexts`'s value to equal to the textViews's text")
		defer { self.waitForExpectations(timeout: 2, handler: nil) }

		let textView = UITextView(frame: CGRect.zero)
		textView.text = "Test"

		textView.reactive.continuousTextValues.observeValues { text in
			XCTAssertEqual(text, textView.text)
			expectation.fulfill()
		}

		NotificationCenter.default.post(name: NSNotification.Name.UITextViewTextDidChange, object: textView)
	}
}
