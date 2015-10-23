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
            .start(Observer(next: { key, group in
                if key {
                    group.start(Observer(next: { evens.append($0) }))
                } else {
                    group.start(Observer(next: { odds.append($0) }))
                }
            },completed: {
                completed = true
            }, interrupted: {
                interrupted = true
            }))

        sink.sendNext(1)
        XCTAssert(evens == [])
        XCTAssert(odds == [1])

        sink.sendNext(2)
        XCTAssert(evens == [2])
        XCTAssert(odds == [1])

        sink.sendNext(3)
        XCTAssert(evens == [2])
        XCTAssert(odds == [1, 3])

        disposable.dispose()

        sink.sendNext(1)
        XCTAssert(interrupted)
        XCTAssertFalse(completed)
    }
}
