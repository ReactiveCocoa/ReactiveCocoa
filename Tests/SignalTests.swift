//
//  SignalTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Rex
import ReactiveCocoa
import XCTest

final class SignalTests: XCTestCase {

    func testFilterMap() {
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var values: [String] = []

        signal
            |> filterMap {
                return $0 % 2 == 0 ? toString($0) : nil
            }
            |> observe(next: values.append)

        sendNext(sink, 1)
        XCTAssert(values == [])

        sendNext(sink, 2)
        XCTAssert(values == ["2"])

        sendNext(sink, 3)
        XCTAssert(values == ["2"])

        sendNext(sink, 6)
        XCTAssert(values == ["2", "6"])
    }

    func testIgnoreErrorCompletion() {
        let (signal, sink) = Signal<Int, NSError>.pipe()
        var completed = false

        signal
            |> ignoreError
            |> observe(completed: {
                completed = true
            })

        sendNext(sink, 1)
        XCTAssertFalse(completed)

        sendError(sink, NSError())
        XCTAssertTrue(completed)
    }

    func testIgnoreErrorInterruption() {
        let (signal, sink) = Signal<Int, NSError>.pipe()
        var interrupted = false

        signal
            |> ignoreError(replacement: .Interrupted)
            |> observe(interrupted: {
                interrupted = true
            })

        sendNext(sink, 1)
        XCTAssertFalse(interrupted)

        sendError(sink, NSError())
        XCTAssertTrue(interrupted)
    }
    
}