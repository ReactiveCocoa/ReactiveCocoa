//
//  UITableViewHeaderFooterViewTests.swift
//  Rex
//
//  Created by David Rodrigues on 19/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveSwift
import ReactiveCocoa
class UITableViewHeaderFooterViewTests: XCTestCase {
    
    func testPrepareForReuse() {

        let hiddenProperty = MutableProperty(false)

        let header = UITableViewHeaderFooterView()

        header.reactive.isHidden <~
            hiddenProperty
                .producer
                .take(until: header.reactive.prepareForReuse)

        XCTAssertFalse(header.isHidden)

        hiddenProperty <~ SignalProducer(value: true)
        XCTAssertTrue(header.isHidden)

        header.prepareForReuse()

        hiddenProperty <~ SignalProducer(value: false)
        XCTAssertTrue(header.isHidden)
    }
}
