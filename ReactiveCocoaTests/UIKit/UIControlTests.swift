import ReactiveSwift
import ReactiveCocoa
import UIKit
import XCTest
import enum Result.NoError

class UIControlTests: XCTestCase {
	weak var _control: UIControl?

	override func tearDown() {
		XCTAssert(_control == nil, "Retain cycle detected in UIControl properties")
		super.tearDown()
	}

	func testEnabledPropertyDoesntCreateRetainCycle() {
		let control = UIControl(frame: CGRect.zero)
		_control = control

		control.reactive.isEnabled <~ SignalProducer(value: false)
		XCTAssert(_control?.isEnabled == false)
	}

	func testSelectedPropertyDoesntCreateRetainCycle() {
		let control = UIControl(frame: CGRect.zero)
		_control = control

		control.reactive.isSelected <~ SignalProducer(value: true)
		XCTAssert(_control?.isSelected == true)
	}

	func testHighlightedPropertyDoesntCreateRetainCycle() {
		let control = UIControl(frame: CGRect.zero)
		_control = control

		control.reactive.isHighlighted <~ SignalProducer(value: true)
		XCTAssert(_control?.isHighlighted == true)
	}

	func testEnabledProperty () {
		let control = UIControl(frame: CGRect.zero)
		control.isEnabled = false

		let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
		control.reactive.isEnabled <~ SignalProducer(signal: pipeSignal)

		observer.send(value: true)
		XCTAssertTrue(control.isEnabled)
		observer.send(value: false)
		XCTAssertFalse(control.isEnabled)
	}

	func testSelectedProperty() {
		let control = UIControl(frame: CGRect.zero)
		control.isSelected = false

		let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
		control.reactive.isSelected <~ SignalProducer(signal: pipeSignal)

		observer.send(value: true)
		XCTAssertTrue(control.isSelected)
		observer.send(value: false)
		XCTAssertFalse(control.isSelected)
	}

	func testHighlightedProperty() {
		let control = UIControl(frame: CGRect.zero)
		control.isHighlighted = false

		let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
		control.reactive.isHighlighted <~ SignalProducer(signal: pipeSignal)

		observer.send(value: true)
		XCTAssertTrue(control.isHighlighted)
		observer.send(value: false)
		XCTAssertFalse(control.isHighlighted)
	}

	func testEnabledAndSelectedProperty() {
		let control = UIControl(frame: CGRect.zero)
		control.isSelected = false
		control.isEnabled = false

		let (pipeSignalSelected, observerSelected) = Signal<Bool, NoError>.pipe()
		let (pipeSignalEnabled, observerEnabled) = Signal<Bool, NoError>.pipe()
		control.reactive.isSelected <~ SignalProducer(signal: pipeSignalSelected)
		control.reactive.isEnabled <~ SignalProducer(signal: pipeSignalEnabled)

		observerSelected.send(value: true)
		observerEnabled.send(value: true)
		XCTAssertTrue(control.isEnabled)
		XCTAssertTrue(control.isSelected)
		observerSelected.send(value: false)
		XCTAssertTrue(control.isEnabled)
		XCTAssertFalse(control.isSelected)
		observerEnabled.send(value: false)
		XCTAssertFalse(control.isEnabled)
		XCTAssertFalse(control.isSelected)
	}
}
