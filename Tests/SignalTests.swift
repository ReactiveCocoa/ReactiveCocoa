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
import enum Result.NoError

final class SignalTests: XCTestCase {

    func testFilterMap() {
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var values: [String] = []

        signal
            .filterMap {
                return $0 % 2 == 0 ? String($0) : nil
            }
            .observeNext { values.append($0) }

        sink.sendNext(1)
        XCTAssert(values == [])

        sink.sendNext(2)
        XCTAssert(values == ["2"])

        sink.sendNext(3)
        XCTAssert(values == ["2"])

        sink.sendNext(6)
        XCTAssert(values == ["2", "6"])
    }

    func testIgnoreErrorCompletion() {
        let (signal, sink) = Signal<Int, TestError>.pipe()
        var completed = false

        signal
            .ignoreError()
            .observeCompleted { completed = true }

        sink.sendNext(1)
        XCTAssertFalse(completed)

        sink.sendFailed(.Default)
        XCTAssertTrue(completed)
    }

    func testIgnoreErrorInterruption() {
        let (signal, sink) = Signal<Int, TestError>.pipe()
        var interrupted = false

        signal
            .ignoreError(replacement: .Interrupted)
            .observeInterrupted { interrupted = true }

        sink.sendNext(1)
        XCTAssertFalse(interrupted)

        sink.sendFailed(.Default)
        XCTAssertTrue(interrupted)
    }

    func testTimeoutAfterTerminating() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var interrupted = false
        var completed = false

        signal
            .timeoutAfter(2, withEvent: .Interrupted, onScheduler: scheduler)
            .observe(Observer(
                completed: { completed = true },
                interrupted: { interrupted = true }
            ))

        scheduler.scheduleAfter(1) { sink.sendCompleted() }

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
            .timeoutAfter(2, withEvent: .Interrupted, onScheduler: scheduler)
            .observe(Observer(
                completed: { completed = true },
                interrupted: { interrupted = true }
            ))

        scheduler.scheduleAfter(3) { sink.sendCompleted() }

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
            .uncollect()
            .observeNext { values.append($0) }

        sink.sendNext([])
        XCTAssert(values.isEmpty)

        sink.sendNext([1])
        XCTAssert(values == [1])

        sink.sendNext([2, 3])
        XCTAssert(values == [1, 2, 3])
    }

    func testDebounceValues() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var value = -1

        signal
            .debounce(1, onScheduler: scheduler)
            .observeNext { value = $0 }

        scheduler.schedule { sink.sendNext(1) }
        scheduler.advance()
        XCTAssertEqual(value, -1)

        scheduler.advanceByInterval(1)
        XCTAssertEqual(value, 1)

        scheduler.schedule { sink.sendNext(2) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { sink.sendNext(3) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.advanceByInterval(1)
        XCTAssertEqual(value, 3)
    }

    func testDebounceFailure() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, TestError>.pipe()
        var value = -1
        var failed = false

        signal
            .debounce(1, onScheduler: scheduler)
            .observe(Observer(
                next: { value = $0 },
                failed: { _ in failed = true }
            ))

        scheduler.schedule { sink.sendNext(1) }
        scheduler.advance()
        XCTAssertEqual(value, -1)

        scheduler.schedule { sink.sendFailed(.Default) }
        scheduler.advance()
        XCTAssertTrue(failed)
        XCTAssertEqual(value, -1)
    }

    func testMuteForValues() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, NoError>.pipe()
        var value = -1

        signal
            .muteFor(1, clock: scheduler)
            .observeNext { value = $0 }

        scheduler.schedule { sink.sendNext(1) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { sink.sendNext(2) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { sink.sendNext(3) }
        scheduler.schedule { sink.sendNext(4) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.advanceByInterval(1)
        XCTAssertEqual(value, 1)

        scheduler.schedule { sink.sendNext(5) }
        scheduler.schedule { sink.sendNext(6) }
        scheduler.advance()
        XCTAssertEqual(value, 5)
    }

    func testMuteForFailure() {
        let scheduler = TestScheduler()
        let (signal, sink) = Signal<Int, TestError>.pipe()
        var value = -1
        var failed = false

        signal
            .muteFor(1, clock: scheduler)
            .observe(Observer(
                next: { value = $0 },
                failed: { _ in failed = true }
            ))

        scheduler.schedule { sink.sendNext(1) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { sink.sendNext(2) }
        scheduler.schedule { sink.sendFailed(.Default) }
        scheduler.advance()
        XCTAssertTrue(failed)
        XCTAssertEqual(value, 1)
    }
}

enum TestError: ErrorType {
    case Default
}