//
//  ActionTests.swift
//  Rex
//
//  Created by Ilya Laryionau on 4/20/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import XCTest
import enum Result.NoError

final class ActionTests: XCTestCase {
    
    enum TestError: Error {
        case unknown
    }

    func testStarted() {
        let action = Action<Void, Void, NoError> { .empty }

        var started = false
        action
            .rex_started
            .observeNext { started = true }

        action
            .apply()
            .start()

        XCTAssertTrue(started)
    }
    
    func testCompleted() {
        let (signal, observer) = Signal<Int, TestError>.pipe()
        let producer = SignalProducer(signal: signal)

        let action = Action { producer }

        var completed = false
        action
            .rex_completed
            .observeNext { completed = true }

        action
            .apply()
            .start()
        
        observer.sendNext(1)
        XCTAssertFalse(completed)

        observer.sendCompleted()
        XCTAssertTrue(completed)
    }
    
    func testCompletedOnFailed() {
        let (signal, observer) = Signal<Int, TestError>.pipe()
        let producer = SignalProducer(signal: signal)

        let action = Action { producer }
        
        var completed = false
        action
            .rex_completed
            .observeNext { completed = true }

        action
            .apply()
            .start()
        
        observer.sendFailed(.unknown)
        XCTAssertFalse(completed)
    }
}
