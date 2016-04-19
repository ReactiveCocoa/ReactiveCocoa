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
import enum Result.NoError

extension UIButton {
    static func button() -> UIButton {
        let button = UIButton(type: UIButtonType.Custom)
        return button;
    }
    
    override public func sendAction(action: Selector, to target: AnyObject?, forEvent event: UIEvent?) {
        target?.performSelector(action, withObject: nil)
    }
}

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
    
    func testTitleProperty() {
        let firstTitle = "First title"
        let secondTitle = "Second title"
        let button = UIButton(frame: CGRectZero)
        let (pipeSignal, observer) = Signal<String, NoError>.pipe()
        button.rex_title <~ SignalProducer(signal: pipeSignal)
        button.setTitle("", forState: .Selected)
        button.setTitle("", forState: .Highlighted)
        
        observer.sendNext(firstTitle)
        XCTAssertEqual(button.titleForState(.Normal), firstTitle)
        XCTAssertEqual(button.titleForState(.Highlighted), "")
        XCTAssertEqual(button.titleForState(.Selected), "")
        
        observer.sendNext(secondTitle)
        XCTAssertEqual(button.titleForState(.Normal), secondTitle)
        XCTAssertEqual(button.titleForState(.Highlighted), "")
        XCTAssertEqual(button.titleForState(.Selected), "")
    }
    
    func testPressedProperty() {
        let button = UIButton(frame: CGRectZero)
        button.enabled = true
        button.userInteractionEnabled = true

        let passed = MutableProperty(false)
        let action = Action<(), Bool, NoError> { _ in
            SignalProducer(value: true)
        }
        
        passed <~ SignalProducer(signal: action.values)
        button.rex_pressed <~ SignalProducer(value: CocoaAction(action, input: ()))
        
        button.sendActionsForControlEvents(.TouchUpInside)
        
        
        XCTAssertTrue(passed.value)
    }
}