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

        1 --> sink
        XCTAssert(values == [])

        2 --> sink
        XCTAssert(values == ["2"])

        3 --> sink
        XCTAssert(values == ["2"])

        6 --> sink
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

        1 --> sink
        XCTAssertFalse(completed)

        NSError() --> sink
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

        1 --> sink
        XCTAssertFalse(interrupted)

        NSError() --> sink
        XCTAssertTrue(interrupted)
    }

    func testTimeoutAfterTerminating() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var interrupted = false
        var completed = false

        signal
            |> timeoutAfter(2, withEvent: .Interrupted, onScheduler: scheduler)
            |> observe(
                completed: { completed = true },
                interrupted: { interrupted = true }
            )

        scheduler.scheduleAfter(1) { sendCompleted(sink) }

        XCTAssertFalse(interrupted)
        XCTAssertFalse(completed)

        scheduler.run()
        XCTAssertTrue(completed)
        XCTAssertFalse(interrupted)
    }

    func testTimeoutAfterTimingOut() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var interrupted = false
        var completed = false

        signal
            |> timeoutAfter(2, withEvent: .Interrupted, onScheduler: scheduler)
            |> observe(
                completed: { completed = true },
                interrupted: { interrupted = true }
            )

        scheduler.scheduleAfter(3) { sendCompleted(sink) }

        XCTAssertFalse(interrupted)
        XCTAssertFalse(completed)

        scheduler.run()
        XCTAssertTrue(interrupted)
        XCTAssertFalse(completed)
    }

    func testUncollect() {
        let (signal, sink) = Signal<[Int], NoError>.pipe()
        var values: [Int] = []

        signal
            |> uncollect
            |> observe(next: {
                values.append($0)
            })

        [] --> sink
        XCTAssert(values.isEmpty)

        [1] --> sink
        XCTAssert(values == [1])

        [2, 3] --> sink
        XCTAssert(values == [1, 2, 3])
    }
}