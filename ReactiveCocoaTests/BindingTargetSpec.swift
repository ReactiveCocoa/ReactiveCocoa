import ReactiveSwift
import ReactiveCocoa
import Result
import Quick
import Nimble

private class Object: NSObject {
	var value: Int = 0

	func increment() {
		value += 1
	}
}

private class NativeObject: ReactiveExtensionsProvider {
	var value: Int = 0

	func increment() {
		value += 1
	}
}

class BindingTargetSpec: QuickSpec {
	override func spec() {
		describe("arbitrary binding target on Objective-C object") {
			it("should call the action") {
				let object = Object()
				let target = object.reactive.makeBindingTarget { (object: Object, nothing: Void) -> Void in
					object.increment()
				}
				expect(object.value) == 0

				let (signal, observer) = Signal<(), NoError>.pipe()
				target <~ signal
				expect(object.value) == 0

				observer.send(value: ())
				expect(object.value) == 1

				observer.send(value: ())
				expect(object.value) == 2
			}

			it("should call the action on the given scheduler") {
				let scheduler = TestScheduler()

				let object = Object()
				let target = object.reactive.makeBindingTarget(on: scheduler) { (object: Object, nothing: Void) -> Void in
					object.increment()
				}
				expect(object.value) == 0

				let (signal, observer) = Signal<(), NoError>.pipe()
				target <~ signal
				observer.send(value: ())
				expect(object.value) == 0

				scheduler.run()
				expect(object.value) == 1

				observer.send(value: ())
				expect(object.value) == 1

				scheduler.run()
				expect(object.value) == 2
			}
		}

		describe("arbitrary binding target on native object") {
			it("should call the action") {
				let object = NativeObject()
				let target = object.reactive.makeBindingTarget { (object: NativeObject, nothing: Void) -> Void in
					object.increment()
				}
				expect(object.value) == 0

				let (signal, observer) = Signal<(), NoError>.pipe()
				target <~ signal
				expect(object.value) == 0

				observer.send(value: ())
				expect(object.value) == 1

				observer.send(value: ())
				expect(object.value) == 2
			}

			it("should call the action on the given scheduler") {
				let scheduler = TestScheduler()

				let object = NativeObject()
				let target = object.reactive.makeBindingTarget(on: scheduler) { (object: NativeObject, nothing: Void) -> Void in
					object.increment()
				}
				expect(object.value) == 0

				let (signal, observer) = Signal<(), NoError>.pipe()
				target <~ signal
				observer.send(value: ())
				expect(object.value) == 0

				scheduler.run()
				expect(object.value) == 1

				observer.send(value: ())
				expect(object.value) == 1

				scheduler.run()
				expect(object.value) == 2
			}
		}


		#if swift(>=3.2)
		describe("key path binding target") {
			it("should update the value") {
				let object = Object()
				expect(object.value) == 0

				let property = MutableProperty(1)
				object.reactive[\.value] <~ property
				expect(object.value) == 1

				property.value = 2
				expect(object.value) == 2
			}

			it("should update the value on the given scheduler") {
				let scheduler = TestScheduler()

				let object = Object()
				let property = MutableProperty(1)
				object.reactive[\.value, on: scheduler] <~ property
				expect(object.value) == 0

				scheduler.run()
				expect(object.value) == 1

				property.value = 2
				expect(object.value) == 1

				scheduler.run()
				expect(object.value) == 2
			}

			it("should work for native swift objects") {
				let object = NativeObject()
				expect(object.value) == 0

				let property = MutableProperty(1)
				object.reactive[\.value] <~ property
				expect(object.value) == 1

				property.value = 2
				expect(object.value) == 2
			}
		}
		#endif
	}
}
