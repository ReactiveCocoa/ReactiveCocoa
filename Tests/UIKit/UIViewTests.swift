//
//  UIViewTests.swift
//  Rex
//
//  Created by Andy Jacobs on 21/10/15.
//  Copyright © 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest

class UIViewTests: XCTestCase {
    
    weak var _view: UIView?
    
    override func tearDown() {
        XCTAssert(_view == nil, "Retain cycle detected in UIView properties")
        super.tearDown()
    }
    
    func testAlphaPropertyDoesntCreateRetainCycle() {
        let view = UIView(frame: CGRectZero)
        _view = view
        
        view.rex_alpha <~ SignalProducer(value: 0.5)
        XCTAssert(_view?.alpha == 0.5)
    }
    
    func testHiddenPropertyDoesntCreateRetainCycle() {
        let view = UIView(frame: CGRectZero)
        _view = view
        
        view.rex_hidden <~ SignalProducer(value: true)
        XCTAssert(_view?.hidden == true)
    }
}