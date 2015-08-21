//
//  UIButtonTests.swift
//  Rex
//
//  Created by Andy Jacobs on 21/08/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest

class UIButtonTests: XCTestCase {

    weak var _button: UIButton?
    
    override func tearDown() {
        XCTAssert(_button == nil, "Retain cycle detected in UIButton properties")
        super.tearDown()
    }
    
    func testEnabledPropertyDoesntCreateRetainCycle() {
        let button = UIButton(frame: CGRectZero)
        _button = button
        
        button.rex_enabled <~ SignalProducer(value: false)
        XCTAssert(_button?.enabled == false)
    }

    func testPressedPropertyDoesntCreateRetainCycle() {
        let button = UIButton(frame: CGRectZero)
        _button = button

        let action = Action<(),(),NoError> {
            SignalProducer(value: ())
        }
        button.rex_pressed <~ SignalProducer(value: CocoaAction(action, input: ()))
    }

    func testTitlePropertyDoesntCreateRetainCycle() {
        let button = UIButton(frame: CGRectZero)
        _button = button

        button.rex_title <~ SignalProducer(value: "button")
        XCTAssert(_button?.titleForState(.Normal) == "button")
    }

}
