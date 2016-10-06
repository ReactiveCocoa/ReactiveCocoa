//
//  UIProgressViewTests.swift
//  Rex
//
//  Created by Tomi Pajunen on 04/05/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import ReactiveCocoa
import UIKit
import XCTest
import enum Result.NoError

class UIProgressViewTests: XCTestCase {
	weak var _progressView: UIProgressView?

	override func tearDown() {
		XCTAssert(_progressView == nil, "Retain cycle detected in UIProgressView properties")
		super.tearDown()
	}

	func testProgressPropertyDoesntCreateRetainCycle() {
		let progressView = UIProgressView(frame: CGRect.zero)
		_progressView = progressView

		progressView.reactive.progress <~ SignalProducer(value: 0.5)
		XCTAssert(_progressView?.progress == 0.5)
	}

	func testProgressProperty() {
		let firstChange: Float = 0.5
		let secondChange: Float = 0.0

		let progressView = UIProgressView(frame: CGRect.zero)
		progressView.progress = 1.0

		let (pipeSignal, observer) = Signal<Float, NoError>.pipe()
		progressView.reactive.progress <~ SignalProducer(signal: pipeSignal)

		observer.send(value: firstChange)
		XCTAssertEqual(progressView.progress, firstChange)
		observer.send(value: secondChange)
		XCTAssertEqual(progressView.progress, secondChange)
	}
}
