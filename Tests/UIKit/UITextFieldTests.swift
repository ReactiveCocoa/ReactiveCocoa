//
//  UITextFieldTests.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest

class UITextFieldTests: XCTestCase {

    func testTextProperty() {
        let expectation = self.expectation(withDescription: "Expected `rex_text`'s value to equal to the textField's text")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }

        let textField = UITextField(frame: CGRect.zero)
        textField.text = "Test"
        
        textField.rex_text.signal.observeNext { text in
            XCTAssertEqual(text, textField.text)
            expectation.fulfill()
        }

#if os(iOS)
        textField.sendActions(for: .editingChanged)
#else
        NSNotificationCenter.defaultCenter().postNotificationName(UITextFieldTextDidChangeNotification, object: textField)
#endif
    }
}
