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
        let `switch` = UISwitch(frame: CGRectZero)
        `switch`.on = false

        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        `switch`.rex_on <~ SignalProducer(signal: pipeSignal)

        observer.sendNext(true)
        XCTAssertTrue(`switch`.on)
        observer.sendNext(false)
        XCTAssertFalse(`switch`.on)

        `switch`.on = true
        `switch`.sendActionsForControlEvents(.ValueChanged)
        XCTAssertTrue(`switch`.rex_on.value)
    }
}
