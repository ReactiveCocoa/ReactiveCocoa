import Foundation
import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble

class InterceptingSpec: QuickSpec {
	override func spec() {
		describe("trigger(for:)") {
			var object: InterceptedObject!
			weak var _object: InterceptedObject?

			beforeEach {
				object = InterceptedObject()
				_object = object
			}

			afterEach {
				object = nil
				expect(_object).to(beNil())
			}

			it("should send a value when the selector is invoked") {
				let signal = object.reactive.trigger(for: #selector(object.increment))

				var counter = 0
				signal.observeValues { counter += 1 }

				expect(counter) == 0
				expect(object.counter) == 0

				object.increment()
				expect(counter) == 1
				expect(object.counter) == 1

				object.increment()
				expect(counter) == 2
				expect(object.counter) == 2
			}

			it("should send a value when the selector is invoked without implementation") {
				let selector = #selector(TestProtocol.optionalMethod)

				let signal = object.reactive.trigger(for: selector,
				                                     from: TestProtocol.self)
				expect(object.responds(to: selector)) == true

				var counter = 0
				signal.observeValues { counter += 1 }

				expect(counter) == 0

				(object as TestProtocol).optionalMethod!()
				expect(counter) == 1

				(object as TestProtocol).optionalMethod!()
				expect(counter) == 2

			}

			it("should complete when the object deinitializes") {
				let signal = object.reactive.trigger(for: #selector(object.increment))

				var isCompleted = false
				signal.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object = nil
				expect(_object).to(beNil())
				expect(isCompleted) == true
			}

			it("should multicast") {
				let signal1 = object.reactive.trigger(for: #selector(object.increment))
				let signal2 = object.reactive.trigger(for: #selector(object.increment))

				var counter1 = 0
				var counter2 = 0
				signal1.observeValues { counter1 += 1 }
				signal2.observeValues { counter2 += 1 }

				expect(counter1) == 0
				expect(counter2) == 0

				object.increment()
				expect(counter1) == 1
				expect(counter2) == 1

				object.increment()
				expect(counter1) == 2
				expect(counter2) == 2
			}

			it("should not deadlock") {
				for _ in 1 ... 10 {
					var isDeadlocked = true

					DispatchQueue.global(priority: .high).async {
						_ = object.reactive.trigger(for: #selector(object.increment))

						DispatchQueue.global(priority: .high).async {
							_ = object.reactive.trigger(for: #selector(object.increment))

							isDeadlocked = false
						}
					}

					expect(isDeadlocked).toEventually(beFalsy())
				}
			}
		}
	}
}

@objc protocol TestProtocol {
	@objc optional func optionalMethod()
}

class InterceptedObject: NSObject, TestProtocol {
	var counter = 0
	var testProtocolCounter = 0

	dynamic func increment() {
		counter += 1
	}
}
