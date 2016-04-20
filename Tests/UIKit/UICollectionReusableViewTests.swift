//
//  UICollectionReusableViewTests.swift
//  Rex
//
//  Created by David Rodrigues on 20/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveCocoa

class UICollectionReusableViewTests: XCTestCase {
    
    func testPrepareForReuse() {

        let hiddenProperty = MutableProperty(false)

        let cell = UICollectionViewCell()

        cell.rex_hidden <~
            hiddenProperty
                .producer
                .takeUntil(cell.rex_prepareForReuse)

        XCTAssertFalse(cell.hidden)

        hiddenProperty <~ SignalProducer(value: true)
        XCTAssertTrue(cell.hidden)

        cell.prepareForReuse()

        hiddenProperty <~ SignalProducer(value: false)
        XCTAssertTrue(cell.hidden)
    }
}
