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

    func testTextProperty() {
        let expectation = self.expectation(description: "Expected `rac_text`'s value to equal to the textField's text")
        defer { self.waitForExpectations(timeout: 2, handler: nil) }

        let textField = UITextField(frame: CGRect.zero)
        textField.text = "Test"
        
        textField.rac.text.signal.observeValues { text in
            XCTAssertEqual(text, textField.text)
            expectation.fulfill()
        }

#if os(iOS)
        textField.sendActions(for: .editingChanged)
#else
        NotificationCenter.default.post(name: .UITextFieldTextDidChange, object: textField)
#endif
    }
}
