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
        
        let expectation = self.expectation(withDescription: "Expected rex_viewDidDisappear to be triggered")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }

        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewDidDisappear.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewDidDisappear(true)
    }
    
    func testViewWillDisappear() {
        
        let expectation = self.expectation(withDescription: "Expected rex_viewWillDisappear to be triggered")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewWillDisappear.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewWillDisappear(true)
    }
    
    func testViewDidAppear() {
        
        let expectation = self.expectation(withDescription: "Expected rex_viewDidAppear to be triggered")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewDidAppear.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewDidAppear(true)
    }
    
    func testViewWillAppear() {
        
        let expectation = self.expectation(withDescription: "Expected rex_viewWillAppear to be triggered")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_viewWillAppear.observeNext {
            expectation.fulfill()
        }
        
        viewController.viewWillAppear(true)
    }
    
    func testDismissViewController_via_property() {
        
        let expectation = self.expectation(withDescription: "Expected rex_dismissModally to be triggered")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_dismissAnimated.signal.observeNext { _ in
            expectation.fulfill()
        }
                
        viewController.rex_dismissAnimated <~ SignalProducer(value: (animated: true, completion: nil))
    }
    
    func testDismissViewController_via_cocoaDismiss() {
        
        let expectation = self.expectation(withDescription: "Expected rex_dismissModally to be triggered")
        defer { self.waitForExpectations(withTimeout: 2, handler: nil) }
        
        let viewController = UIViewController()
        _viewController = viewController
        
        viewController.rex_dismissAnimated.signal.observeNext { _ in
            expectation.fulfill()
        }

        viewController.dismiss(animated: true, completion: nil)
    }
}
