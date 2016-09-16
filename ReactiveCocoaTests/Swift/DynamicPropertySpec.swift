//
//  DynamicPropertySpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

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
				property.producer.startWithNext { value in
					expect(value).notTo(beNil())
					values.append(value!)
				}

				expect(values) == [ 0 ]

				property.value = 1
				expect(values) == [ 0, 1 ]

				object.rac_value = 2
				expect(values) == [ 0, 1, 2 ]
			}

			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object, even if the value actually remains unchanged") {
				var values: [Int] = []
				property.producer.startWithNext { value in
					expect(value).notTo(beNil())
					values.append(value!)
				}

				expect(values) == [ 0 ]

				property.value = 0
				expect(values) == [ 0, 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0, 0 ]
			}

			it("should yield a signal that emits subsequent values for the key path of the underlying object") {
				var values: [Int] = []
				property.signal.observeNext { value in
					expect(value).notTo(beNil())
					values.append(value!)
				}

				expect(values) == []

				property.value = 1
				expect(values) == [ 1 ]

				object.rac_value = 2
				expect(values) == [ 1, 2 ]
			}

			it("should yield a signal that emits subsequent values for the key path of the underlying object, even if the value actually remains unchanged") {
				var values: [Int] = []
				property.signal.observeNext { value in
					expect(value).notTo(beNil())
					values.append(value!)
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
				expect(property.value).to(beNil())
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
				expect(property.value).to(beNil())
			}

			it("should not retain the object"){
				weak var weakObject: ObservableObject? = object
				
				object = nil
				expect(weakObject).to(beNil())
			}

			it("should not be retained by the object"){
				weak var weakProperty: DynamicProperty<Int>? = property

				property = nil
				expect(weakProperty).to(beNil())
			}

			it("should pass through the lifetime of the object"){
				expect(property.lifetime).to(beIdenticalTo(object.rac_lifetime))
			}

			it("should support un-bridged reference types") {
				let dynamicProperty = DynamicProperty<UnbridgedObject>(object: object, keyPath: "rac_reference")
				dynamicProperty.value = UnbridgedObject("foo")
				expect(object.rac_reference.value) == "foo"
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
					observer.sendNext(1)
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
			}
		}
	}
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
	dynamic var rac_reference: UnbridgedObject = UnbridgedObject("")
}

private class UnbridgedObject: NSObject {
	let value: String
	init(_ value: String) {
		self.value = value
	}
}
