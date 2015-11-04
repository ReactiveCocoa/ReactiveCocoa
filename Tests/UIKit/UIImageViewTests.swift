//
//  UIImageViewTests.swift
//  Rex
//
//  Created by Andy Jacobs on 21/10/15.
//  Copyright © 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import XCTest

class UIImageViewTests: XCTestCase {
    
    weak var _imageView: UIImageView?
    
    override func tearDown() {
        XCTAssert(_imageView == nil, "Retain cycle detected in UIImageView properties")
        super.tearDown()
    }
    
    func testImagePropertyDoesntCreateRetainCycle() {
        let imageView = UIImageView(frame: CGRectZero)
        _imageView = imageView
        
        let image = UIImage()
        
        imageView.rex_image <~ SignalProducer(value: image)
        XCTAssert(_imageView?.image == image)
    }
    
    func testHighlightedImagePropertyDoesntCreateRetainCycle() {
        let imageView = UIImageView(frame: CGRectZero)
        _imageView = imageView
        
        let image = UIImage()
        
        imageView.rex_highlightedImage <~ SignalProducer(value: image)
        XCTAssert(_imageView?.highlightedImage == image)
    }
    
    func testImageProperty() {
        let imageView = UIImageView(frame: CGRectZero)
        
        let firstChange = UIImage()
        let secondChange = UIImage()
        
        let (pipeSignal, observer) = Signal<UIImage?, NoError>.pipe()
        imageView.rex_image <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(firstChange)
        XCTAssert(imageView.image === firstChange, "UIImageView.rex_image change #1 failed")
        observer.sendNext(secondChange)
        XCTAssert(imageView.image === secondChange, "UIImageView.rex_image change #2 failed")
    }
    
    func testHighlightedImageProperty() {
        let imageView = UIImageView(frame: CGRectZero)
        
        let firstChange = UIImage()
        let secondChange = UIImage()
        
        let (pipeSignal, observer) = Signal<UIImage?, NoError>.pipe()
        imageView.rex_highlightedImage <~ SignalProducer(signal: pipeSignal)
        
        observer.sendNext(firstChange)
        XCTAssert(imageView.highlightedImage === firstChange, "UIImageView.rex_highlightedImage change #1 failed")
        observer.sendNext(secondChange)
        XCTAssert(imageView.highlightedImage === secondChange, "UIImageView.rex_highlightedImage change #2 failed")
    }
}
