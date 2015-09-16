//
//  SignalProducerTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

@testable import Rex
import ReactiveCocoa
import XCTest

final class SignalProducerTests: XCTestCase {

    func testGroupBy() {
        let (producer, sink) = SignalProducer<Int, NoError>.buffer()
        var evens: [Int] = []
        var odds: [Int] = []
        let disposable = CompositeDisposable()
        var interrupted = false
        var completed = false

        disposable += producer
            .groupBy { $0 % 2 == 0 }
            .start(next: { key, group in
                if key {
                    group.start(next: { evens.append($0) })
                } else {
                    group.start(next: { odds.append($0) })
                }
            },completed: {
                completed = true
            }, interrupted: {
                interrupted = true
            })

        sendNext(sink, 1)
        XCTAssert(evens == [])
        XCTAssert(odds == [1])

        sendNext(sink, 2)
        XCTAssert(evens == [2])
        XCTAssert(odds == [1])

        sendNext(sink, 3)
        XCTAssert(evens == [2])
        XCTAssert(odds == [1, 3])

        disposable.dispose()

        sendNext(sink, 1)
        XCTAssert(interrupted)
        XCTAssertFalse(completed)
    }

    func testCompletionOperator() {
        let (producer, sink) = SignalProducer<Int, NoError>.buffer()
        var evens: [Int] = []
        var odds: [Int] = []
        let disposable = CompositeDisposable()
        var interrupted = false
        var completed = false

        disposable += producer
            .groupBy { $0 % 2 == 0 }
            .start(next: { key, group in
                if key {
                    group.start(next: { evens.append($0) })
                } else {
                    group.start(next: { odds.append($0) })
                }
            },completed: {
                completed = true
            }, interrupted: {
                interrupted = true
            })

        sendNext(sink, 1)
        XCTAssert(evens == [])
        XCTAssert(odds == [1])

        sendCompleted(sink)
        XCTAssert(completed)
        XCTAssertFalse(interrupted)
    }
}
