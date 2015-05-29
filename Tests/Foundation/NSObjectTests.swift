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

        object.rex_producerForKeyPath("string").start(next: { value = $0 })
        XCTAssertEqual(value, "foo")

        object.string = "bar"
        XCTAssertEqual(value, "bar")
    }
}

class Object: NSObject {
    dynamic var string = "foo"
}
