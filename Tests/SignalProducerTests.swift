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
            |> groupBy { $0 % 2 == 0 }
            |> start(next: { key, group in
                if key {
                    group |> start(next: evens.append)
                } else {
                    group |> start(next: odds.append)
                }
                },completed: { completed = true },
                interrupted: {
                    interrupted = true
            })

        1 --> sink
        XCTAssert(evens == [])
        XCTAssert(odds == [1])

        2 --> sink
        XCTAssert(evens == [2])
        XCTAssert(odds == [1])

        3 --> sink
        XCTAssert(evens == [2])
        XCTAssert(odds == [1, 3])
        
        disposable.dispose()
        
        1 --> sink
        XCTAssert(interrupted)
    }
    
    func testCompletionOperator() {
        let (producer, sink) = SignalProducer<Int, NoError>.buffer()
        var evens: [Int] = []
        var odds: [Int] = []
        let disposable = CompositeDisposable()
        var interrupted = false
        var completed = false
        
        disposable += producer
            |> groupBy { $0 % 2 == 0 }
            |> start(next: { key, group in
                if key {
                    group |> start(next: evens.append)
                } else {
                    group |> start(next: odds.append)
                }
                },completed: { completed = true },
                interrupted: {
                    interrupted = true
            })
        
        1 --> sink
        XCTAssert(evens == [])
        XCTAssert(odds == [1])
        
        --|sink
        XCTAssert(completed)
        XCTAssertFalse(interrupted)
    }
}