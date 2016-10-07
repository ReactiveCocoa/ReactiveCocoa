import ReactiveSwift
import ReactiveCocoa
import UIKit
import XCTest
import enum Result.NoError

class UIBarButtonItemTests: XCTestCase {
	weak var _barButtonItem: UIBarButtonItem?

	override func tearDown() {
		XCTAssert(_barButtonItem == nil, "Retain cycle detected in UIBarButtonItem properties")
		super.tearDown()
	}

	func testActionPropertyDoesntCreateRetainCycle() {
		let barButtonItem = UIBarButtonItem()
		_barButtonItem = barButtonItem

		let action = Action<(),(),NoError> {
			SignalProducer(value: ())
		}

		barButtonItem.reactive.pressed = CocoaAction(action)
	}

	func testEnabledProperty() {
		let barButtonItem = UIBarButtonItem()
		barButtonItem.isEnabled = true

		let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
		barButtonItem.reactive.isEnabled <~ SignalProducer(signal: pipeSignal)

		observer.send(value: false)
		XCTAssertFalse(barButtonItem.isEnabled)
		observer.send(value: true)
		XCTAssertTrue(barButtonItem.isEnabled)
	}
}
