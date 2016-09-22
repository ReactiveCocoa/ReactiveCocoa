//
//  UISwitchTests.swift
//  Rex
//
//  Created by David Rodrigues on 07/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveSwift
import ReactiveCocoa
import Result

class UISwitchTests: XCTestCase {
    
    func testOnProperty() {
        let `switch` = UISwitch(frame: CGRect.zero)
        `switch`.isOn = false

        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        `switch`.rex_on <~ SignalProducer(signal: pipeSignal)

        observer.send(value: true)
        XCTAssertTrue(`switch`.isOn)
        observer.send(value: false)
        XCTAssertFalse(`switch`.isOn)

        `switch`.isOn = true
        `switch`.sendActions(for: .valueChanged)
        XCTAssertTrue(`switch`.rex_on.value)
    }
}
