//
//  UITextViewTests.swift
//  Rex
//
//  Created by Rui Peres on 05/04/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest

class UITextViewTests: XCTestCase {
    
    func testTextProperty() {
        let expectation = self.expectationWithDescription("Expected `rex_text`'s value to equal to the textViews's text")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let textView = UITextView(frame: CGRectZero)
        textView.text = "Test"
        
        textView.rex_text.startWithNext { text in
            XCTAssertEqual(text, textView.text)
            expectation.fulfill()
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(UITextViewTextDidChangeNotification, object: textView)
    }
}