import Quick
import Nimble
import ReactiveSwift
import Result

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("Lifetime") {
			it("should complete its lifetime ended signal when the it deinitializes") {
				let object = MutableReference(TestObject())

				var isCompleted = false

				object.value!.lifetime.ended.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object.value = nil
				expect(isCompleted) == true
			}

			it("should complete its lifetime ended signal even if the lifetime object is being retained") {
				let object = MutableReference(TestObject())
				let lifetime = object.value!.lifetime

				var isCompleted = false

				lifetime.ended.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object.value = nil
				expect(isCompleted) == true
			}
		}
	}
}

internal final class MutableReference<Value: AnyObject> {
	var value: Value?
	init(_ value: Value?) {
		self.value = value
	}
}

internal final class TestObject {
	private let token = Lifetime.Token()
	var lifetime: Lifetime { return Lifetime(token) }
}
