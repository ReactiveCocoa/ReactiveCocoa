import XCTest
@testable import ReactiveCocoa
import ReactiveSwift

private final class Receiver: NSObject {
	dynamic func message1() {}

	dynamic func message2() {}
}

class InterceptingTests: XCTestCase {
	fileprivate var receiver: Receiver!

	override func setUp() {
		receiver = Receiver()
	}

	func testDirectMessage() {
		measure {
			for _ in 0 ..< 50000 {
				self.receiver.message1()
			}
		}
	}

	func testInterceptedMessage() {
		_ = receiver.reactive.trigger(for: #selector(receiver.message2))
		measure {
			for _ in 0 ..< 50000 {
				self.receiver.message2()
			}
		}
	}
}
