//
//  UITextFieldTests.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import ReactiveCocoa
import UIKit
import XCTest

class UITextFieldTests: XCTestCase {
	func testTexts() {
		let expectation = self.expectation(description: "Expected `texts`'s value to equal to the textField's text")
		defer { self.waitForExpectations(timeout: 2, handler: nil) }

		let textField = UITextField(frame: CGRect.zero)
		textField.text = "Test"

		textField.reactive.textValues.observeValues { text in
			XCTAssertEqual(text, textField.text)
			expectation.fulfill()
		}

		textField.sendActions(for: .editingDidEnd)
	}

	func testContinuousTexts() {
		let expectation = self.expectation(description: "Expected `continuousTexts`'s value to equal to the textField's text")
		defer { self.waitForExpectations(timeout: 2, handler: nil) }

		let textField = UITextField(frame: CGRect.zero)
		textField.text = "Test"

		textField.reactive.continuousTextValues.observeValues { text in
			XCTAssertEqual(text, textField.text)
			expectation.fulfill()
		}

		textField.sendActions(for: .editingChanged)
	}
}
