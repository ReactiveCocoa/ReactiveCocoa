import XCTest
@testable import ReactiveCocoa
import ReactiveSwift

private let iterationCount = 500

private final class Receiver1: NSObject {
	@objc dynamic func message() {}
}

private final class Receiver2: NSObject {
	@objc dynamic var value: Int = 0
}

private final class Receiver3: NSObject {
	@objc dynamic var value: Int = 0
}

private final class Receiver4: NSObject {
	@objc dynamic var value: Int = 0
}

private final class Receiver5: NSObject {
	@objc dynamic var value: Int = 0
}

private final class Receiver6: NSObject {
	@objc dynamic var value: Int = 0
}

class InterceptingTests: XCTestCase {
	override class func setUp() {
		// Swizzle all classes ahead.

		// General interception.
		let receiver1 = Receiver1()
		_ = receiver1.reactive.trigger(for: #selector(receiver1.message))

		// Setter: RAC then KVO
		let receiver2 = Receiver2()
		_ = receiver2.reactive.trigger(for: #selector(setter: receiver2.value))
		receiver2.reactive.producer(forKeyPath: #keyPath(Receiver2.value)).start()

		// Setter: KVO then RAC
		let receiver3 = Receiver3()
		receiver3.reactive.producer(forKeyPath: #keyPath(Receiver3.value)).start()
		_ = receiver3.reactive.trigger(for: #selector(setter: receiver3.value))

		// RAC swizzled getter, and then KVO swizzled setter.
		let receiver4 = Receiver4()
		_ = receiver4.reactive.trigger(for: #selector(getter: receiver4.value))
		receiver4.reactive.producer(forKeyPath: #keyPath(Receiver4.value)).start()

		// KVO swizzled setter, and then RAC swizzled getter.
		let receiver5 = Receiver5()
		receiver5.reactive.producer(forKeyPath: #keyPath(Receiver5.value)).start()
		_ = receiver5.reactive.trigger(for: #selector(getter: receiver5.value))

		// Normal KVO
		let receiver6 = Receiver6()
		receiver6.reactive.producer(forKeyPath: #keyPath(Receiver6.value)).start()
	}

	func testInterceptedMessage() {
		let receiver = Receiver1()
		_ = receiver.reactive.trigger(for: #selector(receiver.message))

		measure {
			for _ in 0 ..< iterationCount {
				receiver.message()
			}
		}
	}

	func testRACKVOInterceptSetterThenSet() {
		let receiver = Receiver2()

		_ = receiver.reactive.trigger(for: #selector(setter: receiver.value))
		receiver.reactive.producer(forKeyPath: #keyPath(Receiver2.value)).start()

		measure {
			for i in 0 ..< iterationCount {
				receiver.value = i
			}
		}
	}

	func testKVORACInterceptSetterThenSet() {
		let receiver = Receiver3()

		receiver.reactive.producer(forKeyPath: #keyPath(Receiver3.value)).start()
		_ = receiver.reactive.trigger(for: #selector(setter: receiver.value))

		measure {
			for i in 0 ..< iterationCount {
				receiver.value = i
			}
		}
	}

	func testRACKVOInterceptSetterThenGet() {
		let receiver = Receiver4()

		_ = receiver.reactive.trigger(for: #selector(getter: receiver.value))
		receiver.reactive.producer(forKeyPath: #keyPath(Receiver4.value)).start()

		measure {
			for _ in 0 ..< iterationCount {
				_ = receiver.value
			}
		}
	}

	func testKVORACInterceptSetterThenGet() {
		let receiver = Receiver5()

		receiver.reactive.producer(forKeyPath: #keyPath(Receiver5.value)).start()
		_ = receiver.reactive.trigger(for: #selector(getter: receiver.value))

		measure {
			for _ in 0 ..< iterationCount {
				_ = receiver.value
			}
		}
	}

	func testJustKVOInterceptSetterThenSet() {
		let receiver = Receiver6()
		receiver.reactive.producer(forKeyPath: #keyPath(Receiver6.value)).start()

		measure {
			for i in 0 ..< iterationCount {
				receiver.value = i
			}
		}
	}

	func testJustKVOInterceptSetterThenGet() {
		let receiver = Receiver6()
		receiver.reactive.producer(forKeyPath: #keyPath(Receiver6.value)).start()

		measure {
			for _ in 0 ..< iterationCount {
				_ = receiver.value
			}
		}
	}
}
