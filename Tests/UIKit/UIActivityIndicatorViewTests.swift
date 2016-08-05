//
//  UIActivityIndicatorViewTests.swift
//  Rex
//
//  Created by Evgeny Kazakov on 02/07/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import XCTest
import ReactiveCocoa
import Result

class UIActivityIndicatorTests: XCTestCase {

    weak var _activityIndicatorView: UIActivityIndicatorView?

    override func tearDown() {
        XCTAssert(_activityIndicatorView == nil, "Retain cycle detected in UIActivityIndicatorView properties")
        super.tearDown()
    }

    func testAnimatingProperty() {
        let indicatorView = UIActivityIndicatorView(frame: CGRect.zero)
        _activityIndicatorView = indicatorView
        
        let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
        indicatorView.rex_animating <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(true)
        XCTAssertTrue(indicatorView.isAnimating)
        observer.sendNext(false)
        XCTAssertFalse(indicatorView.isAnimating)
    }
}
