//
//  UIDatePickerTests.swift
//  Rex
//
//  Created by Guido Marucci Blas on 3/25/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest
import Rex

class UIDatePickerTests: XCTestCase {
    
    var date: NSDate!
    var picker: UIDatePicker!
    
    override func setUp() {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "MM/dd/YYYY"
        date = formatter.dateFromString("11/29/1988")!
        
        picker = UIDatePicker(frame: CGRectZero)
    }
    
    func testUpdatePickerFromProperty() {
        picker.rex_date.value = date
        
        XCTAssertEqual(picker.date, date)
    }

    // FIXME Can this actually be made to work inside XCTest?
    func _testUpdatePropertyFromPicker() {
        let expectation = self.expectationWithDescription("Expected rex_date to send an event when picker's date value is changed by a UI event")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        picker.rex_date.signal.observeNext { changedDate in
            XCTAssertEqual(changedDate, self.date)
            expectation.fulfill()
        }
        
        picker.date = date
        picker.enabled = true
        picker.userInteractionEnabled = true
        picker.sendActionsForControlEvents(.ValueChanged)
    }
}