import XCTest
@testable import ReactiveCocoa
import ReactiveSwift

private final class Receiver1: NSObject {
	dynamic func message() {}
}

private final class Receiver2: NSObject {
	dynamic var value: Int = 0
}

private final class Receiver3: NSObject {
	dynamic var value: Int = 0
}

class InterceptingTests: XCTestCase {
	func testInterceptedMessage() {
		let receiver = Receiver1()
		_ = receiver.reactive.trigger(for: #selector(receiver.message))

		measure {
			for _ in 0 ..< 50000 {
				receiver.message()
			}
		}
	}

	func testRACKVOInterceptedMessage() {
		let receiver = Receiver2()

		_ = receiver.reactive.trigger(for: #selector(setter: receiver.value))
		receiver.reactive.values(forKeyPath: #keyPath(Receiver2.value)).start()

		measure {
			for i in 0 ..< 50000 {
				receiver.value = i
			}
		}
	}

	func testKVORACInterceptedMessage() {
		let receiver = Receiver3()

		receiver.reactive.values(forKeyPath: #keyPath(Receiver3.value)).start()
		_ = receiver.reactive.trigger(for: #selector(setter: receiver.value))

		measure {
			for i in 0 ..< 50000 {
				receiver.value = i
			}
		}
	}
}
