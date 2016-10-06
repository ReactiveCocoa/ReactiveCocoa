//
//  UICollectionReusableViewTests.swift
//  Rex
//
//  Created by David Rodrigues on 20/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveSwift
import ReactiveCocoa
class UICollectionReusableViewTests: XCTestCase {
    
    func testPrepareForReuse() {

        let hiddenProperty = MutableProperty(false)

        let cell = UICollectionViewCell()

        cell.reactive.isHidden <~
            hiddenProperty
                .producer
                .take(until: cell.reactive.prepareForReuse)

        XCTAssertFalse(cell.isHidden)

        hiddenProperty <~ SignalProducer(value: true)
        XCTAssertTrue(cell.isHidden)

        cell.prepareForReuse()

        hiddenProperty <~ SignalProducer(value: false)
        XCTAssertTrue(cell.isHidden)
    }
}
