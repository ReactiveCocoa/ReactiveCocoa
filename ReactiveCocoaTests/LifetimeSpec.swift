import Foundation
import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble

private final class Token {}

class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("NSObject.reactive.lifetime") {
			var object: NSObject!
			weak var _object: NSObject?

			beforeEach {
				object = NSObject()
				_object = object
			}

			afterEach {
				object = nil
				expect(_object).to(beNil())
			}

			it("should not deadlock") {
				for _ in 1 ... 10 {
					var isDeadlocked = true

					func createQueue() -> DispatchQueue {
						if #available(*, macOS 10.10) {
							return .global(qos: .userInitiated)
						} else {
							return .global(priority: .high)
						}
					}

					createQueue().async {
						_ = object.reactive.lifetime

						createQueue().async {
							_ = object.reactive.lifetime

							isDeadlocked = false
						}
					}

					expect(isDeadlocked).toEventually(beFalsy())
				}
			}
		}

		describe("Signal.take(duringLifetimeOf:)") {
			it("should work with Objective-C objects") {
				var object: NSObject? = NSObject()
				weak var weakObject = object
				var isCompleted = false

				let (signal, observer) = Signal<(), NoError>.pipe()

				withExtendedLifetime(observer) {
					signal
						.take(duringLifetimeOf: object!)
						.observeCompleted { isCompleted = true }

					expect(weakObject).toNot(beNil())
					expect(isCompleted) == false

					object = nil

					expect(weakObject).to(beNil())
					expect(isCompleted) == true
				}
			}

			it("should work with native Swift objects") {
				var object: Token? = Token()
				weak var weakObject = object
				var isCompleted = false

				let (signal, observer) = Signal<(), NoError>.pipe()

				withExtendedLifetime(observer) {
					signal
						.take(duringLifetimeOf: object!)
						.observeCompleted { isCompleted = true }

					expect(weakObject).toNot(beNil())
					expect(isCompleted) == false

					object = nil

					expect(weakObject).to(beNil())
					expect(isCompleted) == true
				}
			}
		}

		describe("SignalProducer.take(duringLifetimeOf:)") {
			it("should work with Objective-C objects") {
				var object: NSObject? = NSObject()
				weak var weakObject = object
				var isCompleted = false

				let (signal, observer) = Signal<(), NoError>.pipe()

				withExtendedLifetime(observer) {
					SignalProducer(signal)
						.take(duringLifetimeOf: object!)
						.startWithCompleted { isCompleted = true }

					expect(weakObject).toNot(beNil())
					expect(isCompleted) == false

					object = nil

					expect(weakObject).to(beNil())
					expect(isCompleted) == true
				}
			}

			it("should work with native Swift objects") {
				var object: Token? = Token()
				weak var weakObject = object
				var isCompleted = false

				let (signal, observer) = Signal<(), NoError>.pipe()

				withExtendedLifetime(observer) {
					SignalProducer(signal)
						.take(duringLifetimeOf: object!)
						.startWithCompleted { isCompleted = true }

					expect(weakObject).toNot(beNil())
					expect(isCompleted) == false

					object = nil

					expect(weakObject).to(beNil())
					expect(isCompleted) == true
				}
			}
		}
	}
}
