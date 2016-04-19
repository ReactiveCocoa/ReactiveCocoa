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
import enum Result.NoError

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
    
    func testSelectedPropertyDoesntCreateRetainCycle() {
        let control = UIControl(frame: CGRectZero)
        _control = control
        
        control.rex_selected <~ SignalProducer(value: true)
        XCTAssert(_control?.selected == true)
    }
    
    func testHighlightedPropertyDoesntCreateRetainCycle() {
        let control = UIControl(frame: CGRectZero)
        _control = control
        
        control.rex_highlighted <~ SignalProducer(value: true)
        XCTAssert(_control?.highlighted == true)
    }
    
    func testEnabledProperty () {
        let control = UIControl(frame: CGRectZero)
        control.enabled = false
        
        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        control.rex_enabled <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(true)
        XCTAssertTrue(control.enabled)
        observer.sendNext(false)
        XCTAssertFalse(control.enabled)
    }
    
    func testSelectedProperty() {
        let control = UIControl(frame: CGRectZero)
        control.selected = false
        
        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        control.rex_selected <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(true)
        XCTAssertTrue(control.selected)
        observer.sendNext(false)
        XCTAssertFalse(control.selected)
    }
    
    func testHighlightedProperty() {
        let control = UIControl(frame: CGRectZero)
        control.highlighted = false
        
        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        control.rex_highlighted <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(true)
        XCTAssertTrue(control.highlighted)
        observer.sendNext(false)
        XCTAssertFalse(control.highlighted)
    }
    
    func testEnabledAndSelectedProperty() {
        let control = UIControl(frame: CGRectZero)
        control.selected = false
        control.enabled = false
        
        let (pipeSignalSelected, observerSelected) = Signal<Bool, NoError>.pipe()
        let (pipeSignalEnabled, observerEnabled) = Signal<Bool, NoError>.pipe()
        control.rex_selected <~ SignalProducer(signal: pipeSignalSelected)
        control.rex_enabled <~ SignalProducer(signal: pipeSignalEnabled)
        
        observerSelected.sendNext(true)
        observerEnabled.sendNext(true)
        XCTAssertTrue(control.enabled)
        XCTAssertTrue(control.selected)
        observerSelected.sendNext(false)
        XCTAssertTrue(control.enabled)
        XCTAssertFalse(control.selected)
        observerEnabled.sendNext(false)
        XCTAssertFalse(control.enabled)
        XCTAssertFalse(control.selected)
    }
}