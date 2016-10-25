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
					var isDeadlock = true

					DispatchQueue.global(priority: .high).async {
						_ = object.reactive.lifetime

						DispatchQueue.global(priority: .high).async {
							_ = object.reactive.lifetime

							isDeadlock = false
						}
					}

					expect(isDeadlock).toEventually(beFalsy())
				}
			}
		}
	}
}
