//
//  UITableViewCellTests.swift
//  Rex
//
//  Created by David Rodrigues on 19/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveCocoa

class UITableViewCellTests: XCTestCase {
    
    func testPrepareForReuse() {

        let titleProperty = MutableProperty("John")

        let cell = UITableViewCell()

        guard let label = cell.textLabel else {
            fatalError()
        }

        label.rex_text <~
            titleProperty
                .producer
                .map(Optional.init) // TODO: Remove in the future, binding with optionals will be available soon in RAC 5. Reference: https://github.com/ReactiveCocoa/ReactiveCocoa/pull/2852
                .takeUntil(cell.rex_prepareForReuse)

        XCTAssertEqual(label.text, "John")

        titleProperty <~ SignalProducer(value: "Frank")
        XCTAssertEqual(label.text, "Frank")

        cell.prepareForReuse()

        titleProperty <~ SignalProducer(value: "Will")
        XCTAssertEqual(label.text, "Frank")
    }
}
