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
}
