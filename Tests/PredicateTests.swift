//
//  PredicateTests.swift
//  Rex
//
//  Created by Neil Pankey on 10/17/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

@testable import Rex
import ReactiveCocoa
import XCTest

final class PredicateTests: XCTestCase {

    func testAndProperty() {
        let lhs = MutableProperty(false), rhs = MutableProperty(false)
        let and = lhs.and(rhs)

        var current: Bool!
        and.producer.startWithNext { current = $0 }
        
        XCTAssertFalse(and.value)
        XCTAssertFalse(current!)

        lhs.value = true
        XCTAssertFalse(and.value)
        XCTAssertFalse(current!)
        
        rhs.value = true
        XCTAssertTrue(and.value)
        XCTAssertTrue(current!)
    }

    func testOrProperty() {
        let lhs = MutableProperty(true), rhs = MutableProperty(true)
        let or = lhs.or(rhs)

        var current: Bool!
        or.producer.startWithNext { current = $0 }
        
        XCTAssertTrue(or.value)
        XCTAssertTrue(current!)

        lhs.value = false
        XCTAssertTrue(or.value)
        XCTAssertTrue(current!)

        rhs.value = false
        XCTAssertFalse(or.value)
        XCTAssertFalse(current!)
    }

    func testNotProperty() {
        let source = MutableProperty(false)
        let not = source.not()

        var current: Bool!
        not.producer.startWithNext { current = $0 }

        XCTAssertTrue(not.value)
        XCTAssertTrue(current!)
        
        source.value = true
        XCTAssertFalse(not.value)
        XCTAssertFalse(current!)
    }
}
