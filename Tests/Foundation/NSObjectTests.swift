//
//  NSObjectTests.swift
//  Rex
//
//  Created by Neil Pankey on 5/28/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

@testable import Rex
import ReactiveCocoa
import XCTest

final class NSObjectTests: XCTestCase {

    func testProducerForKeyPath() {
        let object = Object()
        var value: String = ""

        object.rex_producerForKeyPath("string").start(next: { value = $0 })
        XCTAssertEqual(value, "foo")

        object.string = "bar"
        XCTAssertEqual(value, "bar")
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

        object.rex_stringProperty("string") <~ SignalProducer(value: "Test")
        XCTAssert(_object?.string == "Test")
    }

    func testClassPropertyDoesntCreateRetainCycle() {
        let object = Object()
        _object = object

        object.rex_classProperty("string", placeholder: { _ in "" }) <~ SignalProducer(value: "Test")
        XCTAssert(_object?.string == "Test")
    }
}


class Object: NSObject {
    dynamic var string = "foo"
}
