import Quick
import Nimble
import ReactiveCocoa
import Result

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("SignalProducerProtocol.takeDuring") {
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

		describe("NSObject") {
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
