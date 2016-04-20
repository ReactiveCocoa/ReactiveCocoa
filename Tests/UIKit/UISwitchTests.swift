//
//  UISwitchTests.swift
//  Rex
//
//  Created by David Rodrigues on 07/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveCocoa
import Result

class UISwitchTests: XCTestCase {
    
    func testOnProperty() {
        let s = UISwitch(frame: CGRectZero)
        s.on = false

        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        s.rex_on <~ SignalProducer(signal: pipeSignal)

        observer.sendNext(true)
        XCTAssertTrue(s.on)
        observer.sendNext(false)
        XCTAssertFalse(s.on)
    }
}