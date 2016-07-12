import Quick
import Nimble
import ReactiveCocoa
import Result

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("NSObject lifetime") {
			it("ends when the object is deallocated") {
				let object = MutableReference(TestObject())

				var events: [String] = []

				let lifetime = object.value!.lifetime
				lifetime.observe { event in
					switch event {
					case .next:
						events.append("next")
					case .completed:
						events.append("completed")
					case .failed:
						events.append("failed")
					case .interrupted:
						events.append("interrupted")
					}
				}

				object.value = nil

				expect(events) == ["completed"]

				var isInterrupted = false
				lifetime.observeInterrupted { isInterrupted = true }
				expect(isInterrupted) == true
			}
		}
	}
}

private final class MutableReference<Value: AnyObject> {
	var value: Value?
	init(_ value: Value?) {
		self.value = value
	}
}

private final class TestObject: NSObject {}
