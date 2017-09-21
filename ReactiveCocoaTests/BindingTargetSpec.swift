import ReactiveSwift
import ReactiveCocoa
import Result
import Quick
import Nimble

private class Object: NSObject {
	var value: Int = 0
}

class BindingTargetSpec: QuickSpec {
	override func spec() {
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
		}
		#endif
	}
}
