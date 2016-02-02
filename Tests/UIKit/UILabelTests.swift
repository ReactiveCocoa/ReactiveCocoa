//
//  UILabelTests.swift
//  Rex
//
//  Created by Neil Pankey on 8/20/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest
import enum Result.NoError

class UILabelTests: XCTestCase {

    weak var _label: UILabel?

    override func tearDown() {
        XCTAssert(_label == nil, "Retain cycle detected in UILabel properties")
        super.tearDown()
    }

    func testTextPropertyDoesntCreateRetainCycle() {
        let label = UILabel(frame: CGRectZero)
        _label = label

        label.rex_text <~ SignalProducer(value: "Test")
        XCTAssert(_label?.text == "Test")
    }
    
    func testTextProperty() {
        let firstChange = "first"
        let secondChange = "second"
        
        let label = UILabel(frame: CGRectZero)
        label.text = ""
        
        let (pipeSignal, observer) = Signal<String, NoError>.pipe()
        label.rex_text <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(firstChange)
        XCTAssertEqual(label.text, firstChange)
        observer.sendNext(secondChange)
        XCTAssertEqual(label.text, secondChange)
    }
    
    func testTextColorProperty() {
        let firstChange = UIColor.redColor()
        let secondChange = UIColor.blackColor()
        
        let label = UILabel(frame: CGRectZero)

        let (pipeSignal, observer) = Signal<UIColor, NoError>.pipe()
        label.textColor = UIColor.blackColor()
        label.rex_textColor <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(firstChange)
        XCTAssertEqual(label.textColor, firstChange)
        observer.sendNext(secondChange)
        XCTAssertEqual(label.textColor, secondChange)
    }
}
