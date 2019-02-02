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

class DynamicPropertySpec: QuickSpec {
	override func spec() {

		describe("DynamicProperty with optional value") {
			var object: ObservableObject!
			var property: DynamicProperty<NSNumber?>!

			beforeEach {
				object = ObservableObject()
				expect(object.rac_optional_value) == 0

				property = DynamicProperty<NSNumber?>(object: object, keyPath: "rac_optional_value")
			}

			afterEach {
				object = nil
			}

			let propertyValue: () -> NSNumber? = {
				if let value: Any = property?.value {
					return value as? NSNumber
				} else {
					return nil
				}
			}

			it("should read the underlying object") {
				expect(propertyValue()) == 0

				object.rac_optional_value = nil
				expect(propertyValue()).to(beNil())
			}

			it("should write the underlying object") {
				property.value = nil
				expect(object.rac_optional_value).to(beNil())
				expect(propertyValue()).to(beNil())
			}

			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object") {
				var values: [NSNumber?] = []
				property.producer.startWithValues { value in
					values.append(value)
				}
				
				expect(values).to(equal([0]))

				property.value = nil
				expect(values).to(equal([0, nil]))

				object.rac_optional_value = 2
				expect(values).to(equal([0, nil, 2]))

				object.rac_optional_value = nil
				expect(values).to(equal([0, nil, 2, nil]))
				print(values)
			}
		}

		describe("DynamicProperty") {
			var object: ObservableObject!
			var property: DynamicProperty<Int>!

			let propertyValue: () -> Int? = {
				if let value: Any = property?.value {
					return value as? Int
				} else {
					return nil
				}
			}

			beforeEach {
				object = ObservableObject()
				expect(object.rac_value) == 0

				property = DynamicProperty<Int>(object: object, keyPath: "rac_value")
			}

			afterEach {
				object = nil
			}

			it("should read the underlying object") {
				expect(propertyValue()) == 0

				object.rac_value = 1
				expect(propertyValue()) == 1
			}

			it("should write the underlying object") {
				property.value = 1
				expect(object.rac_value) == 1
				expect(propertyValue()) == 1
			}

			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object") {
				var values: [Int] = []
				property.producer.startWithValues { value in
					values.append(value)
				}

				expect(values) == [ 0 ]

				property.value = 1
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

				property.value = 0
				expect(values) == [ 0, 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0, 0 ]
			}

			it("should yield a signal that emits subsequent values for the key path of the underlying object") {
				var values: [Int] = []
				property.signal.observeValues { value in
					expect(value).notTo(beNil())
					values.append(value)
				}

				expect(values) == []

				property.value = 1
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

				property.value = 0
				expect(values) == [ 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0 ]
			}

			it("should have a completed producer when the underlying object deallocates") {
				var completed = false

				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = DynamicProperty<Int>(object: object, keyPath: "rac_value")

					property.producer.startWithCompleted {
						completed = true
					}

					expect(completed) == false
					expect(property.value).notTo(beNil())
					return property
				}()

				expect(completed).toEventually(beTruthy())
			}

			it("should have a completed signal when the underlying object deallocates") {
				var completed = false

				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = DynamicProperty<Int>(object: object, keyPath: "rac_value")

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
				weak var dynamicProperty: DynamicProperty<Int>? = property

				property = nil
				expect(dynamicProperty).to(beNil())
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

			it("should expose a lifetime that ends upon the deinitialization of its underlying object") {
				var isEnded = false
				property!.lifetime.ended.observeCompleted {
					isEnded = true
				}

				expect(isEnded) == false

				property = nil
				expect(isEnded) == false

				object = nil
				expect(isEnded) == true
			}
		}

		describe("binding") {
			describe("to a dynamic property") {
				var object: ObservableObject!
				var property: DynamicProperty<Int>!

				beforeEach {
					object = ObservableObject()
					expect(object.rac_value) == 0

					property = DynamicProperty<Int>(object: object, keyPath: "rac_value")
				}

				afterEach {
					object = nil
				}

				it("should bridge values sent on a signal to Objective-C") {
					let (signal, observer) = Signal<Int, NoError>.pipe()
					property <~ signal
					observer.send(value: 1)
					expect(object.rac_value) == 1
				}

				it("should bridge values sent on a signal producer to Objective-C") {
					let producer = SignalProducer<Int, NoError>(value: 1)
					property <~ producer
					expect(object.rac_value) == 1
				}

				it("should bridge values from a source property to Objective-C") {
					let source = MutableProperty(1)
					property <~ source
					expect(object.rac_value) == 1
				}

				it("should bridge values sent on a signal to Objective-C, even if the view has deinitialized") {
					let (signal, observer) = Signal<Int, NoError>.pipe()
					property <~ signal
					property = nil

					observer.send(value: 1)
					expect(object.rac_value) == 1
				}

				it("should bridge values sent on a signal producer to Objective-C, even if the view has deinitialized") {
					let producer = SignalProducer<Int, NoError>(value: 1)
					property <~ producer
					property = nil

					expect(object.rac_value) == 1
				}

				it("should bridge values from a source property to Objective-C, even if the view has deinitialized") {
					let source = MutableProperty(1)
					property <~ source
					property = nil

					expect(object.rac_value) == 1
				}
			}
		}
	}
}

private class ObservableObject: NSObject {
	@objc dynamic var rac_value: Int = 0
	@objc dynamic var rac_optional_value: NSNumber? = 0
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
