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
}
