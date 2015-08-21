//
//  UIControlTests.swift
//  Rex
//
//  Created by Andy Jacobs on 21/08/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest

class UIControlTests: XCTestCase {
    
    weak var _control: UIControl?
    
    override func tearDown() {
        XCTAssert(_control == nil, "Retain cycle detected in UIControl properties")
        super.tearDown()
    }
    
    func testEnabledPropertyDoesntCreateRetainCycle() {
        let control = UIControl(frame: CGRectZero)
        _control = control
        
        control.rex_enabled <~ SignalProducer(value: false)
        XCTAssert(_control?.enabled == false)
    }
}
