//
//  NSObjectTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/28/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Rex
import ReactiveCocoa
import XCTest

final class NSObjectTests: XCTestCase {
    
    func testProducerForKeyPath() {
        let object = Object()
        var value: String = ""

        object.rex_producerForKeyPath("string").startWithNext { value = $0 }
        XCTAssertEqual(value, "foo")

        object.string = "bar"
        XCTAssertEqual(value, "bar")
    }
    
    func testObjectsWillBeDeallocatedSignal() {
        
        let expectation = self.expectation(withDescription: "Expected timer to send `completed` event when object deallocates")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }
        
        let object = Object()

        timer(interval: 1, on: QueueScheduler(name: "test.queue"))
            .take(until: object.rex_willDealloc)
            .startWithCompleted {
                expectation.fulfill()
        }
    }
}

final class NSObjectDeallocTests: XCTestCase {

    weak var _object: Object?

    override func tearDown() {
        XCTAssert(_object == nil, "Retain cycle detected")
        super.tearDown()
    }

    func testStringPropertyDoesntCreateRetainCycle() {
        let object = Object()
        _object = object

        associatedProperty(object, keyPath: "string") <~ SignalProducer(value: "Test")
        XCTAssert(_object?.string == "Test")
    }

    func testClassPropertyDoesntCreateRetainCycle() {
        let object = Object()
        _object = object

        associatedProperty(object, keyPath: "string", placeholder: { _ in "" }) <~ SignalProducer(value: "Test")
        XCTAssert(_object?.string == "Test")
    }
}

class Object: NSObject {
    dynamic var string = "foo"
}
