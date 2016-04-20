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
        let expectation = self.expectationWithDescription("Expected `rex_text`'s value to equal to the textField's text")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let textField = UITextField(frame: CGRectZero)
        textField.text = "Test"
        
        textField.rex_text.startWithNext { text in
            XCTAssertEqual(text, textField.text)
            expectation.fulfill()
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(UITextFieldTextDidChangeNotification, object: textField)
    }
}