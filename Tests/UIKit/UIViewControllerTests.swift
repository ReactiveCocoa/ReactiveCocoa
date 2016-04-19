//
//  UIViewControllerTests.swift
//  Rex
//
//  Created by Rui Peres on 16/04/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest
import enum Result.NoError

class UIViewControllerTests: XCTestCase {
    
    weak var _viewController: UIViewController?
    
    override func tearDown() {
        XCTAssert(_viewController == nil, "Retain cycle detected in UIViewController properties")
        super.tearDown()
    }
    
    func testViewDidDisappear() {
        
        let expectation = self.expectationWithDescription("Expected rex_viewDidDisappearSignal to be triggered")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }

        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewDidDisappearSignal.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewDidDisappear(true)
    }
    
    func testViewWillDisappear() {
        
        let expectation = self.expectationWithDescription("Expected rex_viewWillDisappearSignal to be triggered")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewWillDisappearSignal.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewWillDisappear(true)
    }
    
    func testViewDidAppear() {
        
        let expectation = self.expectationWithDescription("Expected rex_viewDidAppearSignal to be triggered")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewDidAppearSignal.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewDidAppear(true)
    }
    
    func testViewWillAppear() {
        
        let expectation = self.expectationWithDescription("Expected rex_viewWillAppearSignal to be triggered")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewWillAppearSignal.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewWillAppear(true)
    }
    
    func testDismissViewController_via_property() {
        
        let expectation = self.expectationWithDescription("Expected rex_dismissModally to be triggered")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_dismissAnimated.signal.observeNext { _ in
            expectation.fulfill()
        }
                
        viewController.rex_dismissAnimated <~ SignalProducer(value: (animated: true, completion: nil))
    }
    
    func testDismissViewController_via_cocoaDismiss() {
        
        let expectation = self.expectationWithDescription("Expected rex_dismissModally to be triggered")
        defer { self.waitForExpectationsWithTimeout(2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_dismissAnimated.signal.observeNext { _ in
            expectation.fulfill()
        }

        viewController.dismissViewControllerAnimated(true, completion: nil)
    }
}