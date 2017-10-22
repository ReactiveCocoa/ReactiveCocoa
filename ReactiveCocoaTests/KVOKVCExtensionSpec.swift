import ReactiveSwift
import Result
import Nimble
import Quick
import ReactiveCocoa

private let initialPropertyValue = "InitialValue"
private let subsequentPropertyValue = "SubsequentValue"
private let finalPropertyValue = "FinalValue"

private let initialOtherPropertyValue = "InitialOtherValue"
private let subsequentOtherPropertyValue = "SubsequentOtherValue"
private let finalOtherPropertyValue = "FinalOtherValue"

class KVOKVCExtensionSpec: QuickSpec {
	override func spec() {
		describe("Property(object:keyPath:)") {
			var object: ObservableObject!
			var property: Property<Int>!

			beforeEach {
				object = ObservableObject()
				expect(object.rac_value) == 0

				property = Property<Int>(object: object, keyPath: "rac_value")
			}

			afterEach {
				object = nil
			}

			it("should read the underlying object") {
				expect(property.value) == 0

				object.rac_value = 1
				expect(property.value) == 1
			}

			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object") {
				var values: [Int] = []
				property.producer.startWithValues { value in
					values.append(value)
				}

				expect(values) == [ 0 ]

				object.rac_value = 1
				expect(values) == [ 0, 1 ]

				object.rac_value = 2
				expect(values) == [ 0, 1, 2 ]
			}

			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object, even if the value actually remains unchanged") {
				var values: [Int] = []
				property.producer.startWithValues { value in
					values.append(value)
				}

				expect(values) == [ 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0, 0 ]
			}

			it("should yield a signal that emits subsequent values for the key path of the underlying object") {
				var values: [Int] = []
				property.signal.observeValues { value in
					values.append(value)
				}

				expect(values) == []

				object.rac_value = 1
				expect(values) == [ 1 ]

				object.rac_value = 2
				expect(values) == [ 1, 2 ]
			}

			it("should yield a signal that emits subsequent values for the key path of the underlying object, even if the value actually remains unchanged") {
				var values: [Int] = []
				property.signal.observeValues { value in
					values.append(value)
				}

				expect(values) == []

				object.rac_value = 0
				expect(values) == [ 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0 ]
			}

			it("should have a completed producer when the underlying object deallocates") {
				var completed = false

				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = Property<Int>(object: object, keyPath: "rac_value")

					property.producer.startWithCompleted {
						completed = true
					}

					expect(completed) == false
					expect(property.value) == 0
					return property
				}()

				expect(completed).toEventually(beTruthy())
			}

			it("should have a completed signal when the underlying object deallocates") {
				var completed = false

				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = Property<Int>(object: object, keyPath: "rac_value")

					property.signal.observeCompleted {
						completed = true
					}

					expect(completed) == false
					expect(property.value).notTo(beNil())
					return property
				}()

				expect(completed).toEventually(beTruthy())
			}

			it("should not be retained by its underlying object"){
				weak var weakProperty: Property<Int>? = property

				property = nil
				expect(weakProperty).to(beNil())
			}

			it("should be accessible even if the underlying object has deinitialized") {
				object.rac_value = .max
				object = nil

				expect(property.value) == Int.max

				var latestValue: Int?
				property.producer.startWithValues { latestValue = $0 }
				expect(latestValue) == .max

				var isInterrupted = false
				property.signal.observeInterrupted { isInterrupted = true }
				expect(isInterrupted) == true
			}

			it("should support un-bridged reference types") {
				let dynamicProperty = DynamicProperty<UnbridgedObject>(object: object, keyPath: "rac_reference")
				dynamicProperty.value = UnbridgedObject("foo")
				expect(object.rac_reference.value) == "foo"
			}

			it("should support un-bridged value types") {
				let dynamicProperty = DynamicProperty<UnbridgedValue>(object: object, keyPath: "rac_unbridged")
				dynamicProperty.value = .changed
				expect(object.rac_unbridged as? UnbridgedValue) == UnbridgedValue.changed
			}
		}
	}
}

private class ObservableObject: NSObject {
	@objc dynamic var rac_value: Int = 0
	@objc dynamic var rac_reference: UnbridgedObject = UnbridgedObject("")
	@objc dynamic var rac_unbridged: Any = UnbridgedValue.starting
}

private class UnbridgedObject: NSObject {
	let value: String
	init(_ value: String) {
		self.value = value
	}
}

private enum UnbridgedValue {
	case starting
	case changed
}
