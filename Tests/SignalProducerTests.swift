//
//  SignalProducerTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Rex
import ReactiveCocoa
import XCTest
import enum Result.NoError

final class SignalProducerTests: XCTestCase {

    func testGroupBy() {
        let (signal, observer) = Signal<Int, NoError>.pipe()
        let producer = SignalProducer(signal: signal)

        var evens: [Int] = []
        var odds: [Int] = []
        let disposable = CompositeDisposable()
        var interrupted = false
        var completed = false

        disposable += producer
            .group { $0 % 2 == 0 }
            .start(Observer(next: { key, group in
                if key {
                    group.startWithNext { evens.append($0) }
                } else {
                    group.startWithNext { odds.append($0) }
                }
            },completed: {
                completed = true
            }, interrupted: {
                interrupted = true
            }))

        observer.sendNext(1)
        XCTAssert(evens == [])
        XCTAssert(odds == [1])

        observer.sendNext(2)
        XCTAssert(evens == [2])
        XCTAssert(odds == [1])

        observer.sendNext(3)
        XCTAssert(evens == [2])
        XCTAssert(odds == [1, 3])

        disposable.dispose()

        observer.sendNext(1)
        XCTAssert(interrupted)
        XCTAssertFalse(completed)
    }

    func testDeferred() {
        let scheduler = TestScheduler()

        var deferred = false
        let producer = SignalProducer<(), NoError> { _ in deferred = true }

        var started = false
        producer
            .defer(by: 1, on: scheduler)
            .on(started: { started = true })
            .start()

        XCTAssertTrue(started)
        XCTAssertFalse(deferred)

        scheduler.advance()
        XCTAssertFalse(deferred)

        scheduler.advance(by: 0.9)
        XCTAssertFalse(deferred)

        scheduler.advance(by: 0.2)
        XCTAssertTrue(deferred)
    }

    func testDeferredRetry() {
        let scheduler = TestScheduler()

        var count = 0
        let producer = SignalProducer<Int, TestError> { observer, _ in
            if count < 2 {
                scheduler.schedule { observer.sendNext(count) }
                scheduler.schedule { observer.sendFailed(.default) }
            } else {
                scheduler.schedule { observer.sendCompleted() }
            }
            count += 1
        }

        var value = -1
        var completed = false
        producer
            .deferredRetry(interval: 1, on: scheduler)
            .start(Observer(
                next: { value = $0 },
                completed: { completed = true }
            ))

        XCTAssertEqual(count, 1)
        XCTAssertEqual(value, -1)

        scheduler.advance()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(value, 1)
        XCTAssertFalse(completed)

        scheduler.advance(by: 1)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(value, 2)
        XCTAssertFalse(completed)

        scheduler.advance(by: 1)
        XCTAssertEqual(count, 3)
        XCTAssertEqual(value, 2)
        XCTAssertTrue(completed)
    }

    func testDeferredRetryFailure() {
        let scheduler = TestScheduler()

        var count = 0
        let producer = SignalProducer<Int, TestError> { observer, _ in
            observer.sendNext(count)
            observer.sendFailed(.default)
            count += 1
        }

        var value = -1
        var failed = false
        producer
            .deferredRetry(interval: 1, on: scheduler, count: 2)
            .start(Observer(
                next: { value = $0 },
                failed: { _ in failed = true }
            ))

        XCTAssertEqual(count, 1)
        XCTAssertEqual(value, 0)

        scheduler.advance()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(value, 0)
        XCTAssertFalse(failed)

        scheduler.advance(by: 1)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(value, 1)
        XCTAssertFalse(failed)

        scheduler.advance(by: 1)
        XCTAssertEqual(count, 3)
        XCTAssertEqual(value, 2)
        XCTAssertTrue(failed)
    }
}
