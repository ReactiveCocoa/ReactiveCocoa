import ReactiveSwift
import ReactiveCocoa
import UIKit
import XCTest
import enum Result.NoError

class UILabelTests: XCTestCase {
	weak var _label: UILabel?

	override func tearDown() {
		XCTAssert(_label == nil, "Retain cycle detected in UILabel properties")
		super.tearDown()
	}

	func testTextPropertyDoesntCreateRetainCycle() {
		let label = UILabel(frame: CGRect.zero)
		_label = label

		label.reactive.text <~ SignalProducer(value: "Test")
		XCTAssert(_label?.text == "Test")
	}

	func testTextProperty() {
		let firstChange = "first"
		let secondChange = "second"

		let label = UILabel(frame: CGRect.zero)
		label.text = ""

		let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
		label.reactive.text <~ SignalProducer(signal: pipeSignal)

		observer.send(value: firstChange)
		XCTAssertEqual(label.text, firstChange)
		observer.send(value: secondChange)
		XCTAssertEqual(label.text, secondChange)
		observer.send(value: nil)
		XCTAssertNil(label.text)
	}

	func testAttributedTextPropertyDoesntCreateRetainCycle() {
		let label = UILabel(frame: CGRect.zero)
		_label = label

		label.reactive.attributedText <~ SignalProducer(value: NSAttributedString(string: "Test"))
		XCTAssert(_label?.attributedText?.string == "Test")
	}

	func testAttributedTextProperty() {
		let firstChange = NSAttributedString(string: "first")
		let secondChange = NSAttributedString(string: "second")

		let label = UILabel(frame: CGRect.zero)
		label.attributedText = NSAttributedString(string: "")

		let (pipeSignal, observer) = Signal<NSAttributedString?, NoError>.pipe()
		label.reactive.attributedText <~ SignalProducer(signal: pipeSignal)

		observer.send(value: firstChange)
		XCTAssertEqual(label.attributedText, firstChange)
		observer.send(value: secondChange)
		XCTAssertEqual(label.attributedText, secondChange)
	}

	func testTextColorProperty() {
		let firstChange = UIColor.red
		let secondChange = UIColor.black

		let label = UILabel(frame: CGRect.zero)

		let (pipeSignal, observer) = Signal<UIColor, NoError>.pipe()
		label.textColor = UIColor.black
		label.reactive.textColor <~ SignalProducer(signal: pipeSignal)

		observer.send(value: firstChange)
		XCTAssertEqual(label.textColor, firstChange)
		observer.send(value: secondChange)
		XCTAssertEqual(label.textColor, secondChange)
	}
}
