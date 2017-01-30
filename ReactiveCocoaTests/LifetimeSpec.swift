import Foundation
import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble

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
	}
}
