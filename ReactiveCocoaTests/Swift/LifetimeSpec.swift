import Quick
import Nimble
import ReactiveCocoa
import Result

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("take during") {
			it("completes a signal when the lifetime ends") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				let object = MutableReference(TestObject())

				let output = signal.take(during: object.value!.lifetime)

				var results: [Int] = []
				output.observeNext { results.append($0) }

				observer.sendNext(1)
				observer.sendNext(2)
				object.value = nil
				observer.sendNext(3)

				expect(results) == [1, 2]
			}

			it("completes a signal producer when the lifetime ends") {
				let (producer, observer) = Signal<Int, NoError>.pipe()
				let object = MutableReference(TestObject())

				let output = producer.take(during: object.value!.lifetime)

				var results: [Int] = []
				output.observeNext { results.append($0) }

				observer.sendNext(1)
				observer.sendNext(2)
				object.value = nil
				observer.sendNext(3)

				expect(results) == [1, 2]
			}
		}

		describe("NSObject lifetime") {
			it("should complete its signal even if it is being retained") {
				let object = MutableReference(TestObject())

				var events: [String] = []

				object.value!.lifetime.ended.observe { event in
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

				let lifetime = object.value!.lifetime

				// Suppress the "never read" warning.
				_ = lifetime

				object.value = nil

				expect(events) == ["completed"]
			}

			it("ends when the object is deallocated") {
				let object = MutableReference(TestObject())

				var events: [String] = []

				object.value!.lifetime.ended.observe { event in
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

private final class TestObject {
	private let token = Lifetime.Token()
	var lifetime: Lifetime { return Lifetime(token) }
}
