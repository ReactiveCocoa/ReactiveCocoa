//
//  SignalTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import XCTest
import enum Result.NoError

final class SignalTests: XCTestCase {

    func testFilterMap() {
        let (signal, observer) = Signal<Int, NoError>.pipe()
        var values: [String] = []

        signal
            .filterMap {
                return $0 % 2 == 0 ? String($0) : nil
            }
            .observeNext { values.append($0) }

        observer.sendNext(1)
        XCTAssert(values == [])

        observer.sendNext(2)
        XCTAssert(values == ["2"])

        observer.sendNext(3)
        XCTAssert(values == ["2"])

        observer.sendNext(6)
        XCTAssert(values == ["2", "6"])
    }

    func testIgnoreErrorCompletion() {
        let (signal, observer) = Signal<Int, TestError>.pipe()
        var completed = false

        signal
            .ignoreError()
            .observeCompleted { completed = true }

        observer.sendNext(1)
        XCTAssertFalse(completed)

        observer.sendFailed(.default)
        XCTAssertTrue(completed)
    }

    func testIgnoreErrorInterruption() {
        let (signal, observer) = Signal<Int, TestError>.pipe()
        var interrupted = false

        signal
            .ignoreError(replacement: .interrupted)
            .observeInterrupted { interrupted = true }

        observer.sendNext(1)
        XCTAssertFalse(interrupted)

        observer.sendFailed(.default)
        XCTAssertTrue(interrupted)
    }

    func testTimeoutAfterTerminating() {
        let scheduler = TestScheduler()
        let (signal, observer) = Signal<Int, NoError>.pipe()
        var interrupted = false
        var completed = false

        signal
            .timeout(after: 2, with: .interrupted, on: scheduler)
            .observe(Observer(
                completed: { completed = true },
                interrupted: { interrupted = true }
            ))

        scheduler.schedule(after: 1) { observer.sendCompleted() }

        XCTAssertFalse(interrupted)
        XCTAssertFalse(completed)

        scheduler.run()
        XCTAssertTrue(completed)
        XCTAssertFalse(interrupted)
    }

    func testTimeoutAfterTimingOut() {
        let scheduler = TestScheduler()
        let (signal, observer) = Signal<Int, NoError>.pipe()
        var interrupted = false
        var completed = false

        signal
            .timeout(after: 2, with: .interrupted, on: scheduler)
            .observe(Observer(
                completed: { completed = true },
                interrupted: { interrupted = true }
            ))

        scheduler.schedule(after: 3) { observer.sendCompleted() }

        XCTAssertFalse(interrupted)
        XCTAssertFalse(completed)

        scheduler.run()
        XCTAssertTrue(interrupted)
        XCTAssertFalse(completed)
    }

    func testUncollect() {
        let (signal, observer) = Signal<[Int], NoError>.pipe()
        var values: [Int] = []

        signal
            .uncollect()
            .observeNext { values.append($0) }

        observer.sendNext([])
        XCTAssert(values.isEmpty)

        observer.sendNext([1])
        XCTAssert(values == [1])

        observer.sendNext([2, 3])
        XCTAssert(values == [1, 2, 3])
    }

    func testMuteForValues() {
        let scheduler = TestScheduler()
        let (signal, observer) = Signal<Int, NoError>.pipe()
        var value = -1

        signal
            .mute(for: 1, clock: scheduler)
            .observeNext { value = $0 }

        scheduler.schedule { observer.sendNext(1) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { observer.sendNext(2) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { observer.sendNext(3) }
        scheduler.schedule { observer.sendNext(4) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.advance(by: 1)
        XCTAssertEqual(value, 1)

        scheduler.schedule { observer.sendNext(5) }
        scheduler.schedule { observer.sendNext(6) }
        scheduler.advance()
        XCTAssertEqual(value, 5)
    }

    func testMuteForFailure() {
        let scheduler = TestScheduler()
        let (signal, observer) = Signal<Int, TestError>.pipe()
        var value = -1
        var failed = false

        signal
            .mute(for: 1, clock: scheduler)
            .observe(Observer(
                next: { value = $0 },
                failed: { _ in failed = true }
            ))

        scheduler.schedule { observer.sendNext(1) }
        scheduler.advance()
        XCTAssertEqual(value, 1)

        scheduler.schedule { observer.sendNext(2) }
        scheduler.schedule { observer.sendFailed(.default) }
        scheduler.advance()
        XCTAssertTrue(failed)
        XCTAssertEqual(value, 1)
    }
}

enum TestError: Error {
    case `default`
}
