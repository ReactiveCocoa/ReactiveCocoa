//
//  PropertyTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/29/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Rex
import ReactiveCocoa
import XCTest

final class PropertyTests: XCTestCase {

    func testSignalPropertyValues() {
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var property: SignalProperty? = SignalProperty(0, signal)

        var latest = -1
        property?.producer.start(next: {
            println("Really?")
            latest = $0
        })

        XCTAssert(latest == 0)

        sendNext(sink, 1)
        XCTAssert(latest == 1)
    }

    func testSignalPropertyLifetime() {
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var property: SignalProperty? = SignalProperty(0, signal)

        var completed = false
        property?.producer.start(completed: {
            println("Really?")
            completed = true
        })

        println("Before")
        property = nil
        println("After")
        XCTAssert(completed)
    }
}
