import XCTest
import ReactiveSwift
import ReactiveCocoa
import Result

class UISegmentedControlTests: XCTestCase {
	func testSelectedSegmentIndexProperty() {
		let s = UISegmentedControl(items: ["0", "1", "2"])
		s.selectedSegmentIndex = UISegmentedControlNoSegment
		XCTAssertEqual(s.numberOfSegments, 3)

		let (pipeSignal, observer) = Signal<Int, NoError>.pipe()
		s.reactive.selectedSegmentIndex <~ SignalProducer(signal: pipeSignal)

		XCTAssertEqual(s.selectedSegmentIndex, UISegmentedControlNoSegment)
		observer.send(value: 1)
		XCTAssertEqual(s.selectedSegmentIndex, 1)
		observer.send(value: 2)
		XCTAssertEqual(s.selectedSegmentIndex, 2)
	}
}
