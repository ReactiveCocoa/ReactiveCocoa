import Quick
import Nimble
import ReactiveCocoa
import Result

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("Signal.take(withinLifetime:)") {
			it("should end when the object deinitializes") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				var object: NSObject? = NSObject()
				var values = [Int]()

				signal.take(withinLifetimeOf: object!)
					.observeNext { value in values.append(value) }

				observer.sendNext(1)
				observer.sendNext(2)
				expect(values) == [1, 2]

				object = nil

				observer.sendNext(3)
				expect(values) == [1, 2]
			}
		}

		describe("SignalProducer.take(withinLifetime:)") {
			it("should end when the object deinitializes") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				let producer = SignalProducer(signal: signal)

				var object: NSObject? = NSObject()
				var values = [Int]()

				producer.take(withinLifetimeOf: object!)
					.startWithNext { value in values.append(value) }

				observer.sendNext(1)
				observer.sendNext(2)
				expect(values) == [1, 2]

				object = nil

				observer.sendNext(3)
				expect(values) == [1, 2]
			}
		}

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
