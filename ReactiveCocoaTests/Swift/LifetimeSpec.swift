import Quick
import Nimble
import ReactiveCocoa
import Result

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("take within") {
			it("completes a signal when the lifetime ends") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				let object = MutableReference(TestObject())

				let output = signal.takeWithin(object.value!.lifetime)

				var results: [Int] = []
				output.observeNext { results.append($0) }

				observer.sendNext(1)
				observer.sendNext(2)
				object.value = nil
				observer.sendNext(3)

				expect(results) == [1, 2]
			}

			it("completes a signal producer when the lifetime ends") {
				let (producer, observer) = SignalProducer<Int, NoError>.buffer(1)
				let object = MutableReference(TestObject())

				let output = producer.takeWithin(object.value!.lifetime)

				var results: [Int] = []
				output.startWithNext { results.append($0) }

				observer.sendNext(1)
				observer.sendNext(2)
				object.value = nil
				observer.sendNext(3)

				expect(results) == [1, 2]
			}
		}

		describe("NSObject lifetime") {
			it("ends when the object is deallocated") {
				let object = MutableReference(TestObject())

				var events: [String] = []

				object.value!.lifetime.ended.observe { event in
					switch event {
					case .Next:
						events.append("next")
					case .Completed:
						events.append("completed")
					case .Failed:
						events.append("failed")
					case .Interrupted:
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
	let lifetime = Lifetime()
}
