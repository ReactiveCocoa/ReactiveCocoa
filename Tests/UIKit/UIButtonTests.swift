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

public extension UIButton {
    static func button() -> UIButton {
        let button = UIButton(type: UIButtonType.Custom)
        return button;
    }
    
    override func sendAction(action: Selector, to target: AnyObject?, forEvent event: UIEvent?) {
        target?.performSelector(action)
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
        XCTAssert(button.titleForState(.Normal) == firstTitle, "#1 change of the title for .Normal state failed [UIButton]")
        XCTAssert(button.titleForState(.Highlighted) == "", "#1 .Highlighted state shouldn't change [UIButton]")
        XCTAssert(button.titleForState(.Selected) == "", "#1 .Selected state shouldn't change [UIButton]")
        
        observer.sendNext(secondTitle)
        XCTAssert(button.titleForState(.Normal) == secondTitle, "#2 change of the title for .Normal state failed [UIButton]")
        XCTAssert(button.titleForState(.Highlighted) == "", "#2 .Highlighted state shouldn't change [UIButton]")
        XCTAssert(button.titleForState(.Selected) == "", "#2 .Selected state shouldn't change [UIButton]")
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
        button.rex_pressed.value = CocoaAction(action, input: ())
        
        button.sendActionsForControlEvents(.TouchUpInside)
        
        XCTAssert(passed.value == true, "Press doesn't perform cocoa action")
    }
    
    

}
