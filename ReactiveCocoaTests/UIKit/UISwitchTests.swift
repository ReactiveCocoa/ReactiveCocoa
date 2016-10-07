import XCTest
import ReactiveSwift
import ReactiveCocoa
import Result

class UISwitchTests: XCTestCase {
	func testOnProperty() {
		let toggle = UISwitch(frame: CGRect.zero)
		toggle.isOn = false

		let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
		toggle.reactive.isOn <~ SignalProducer(signal: pipeSignal)

		observer.send(value: true)
		XCTAssertTrue(toggle.isOn)
		observer.send(value: false)
		XCTAssertFalse(toggle.isOn)

		var latestValue: Bool?
		toggle.reactive.isOnValues.observeValues { latestValue = $0 }

		toggle.isOn = true
		toggle.sendActions(for: .valueChanged)
		XCTAssertTrue(latestValue!)
	}
}
