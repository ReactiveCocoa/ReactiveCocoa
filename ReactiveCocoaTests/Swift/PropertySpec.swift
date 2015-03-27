//
//  PropertySpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

private let initialPropertyValue = "InitialValue"
private let subsequentPropertyValue = "SubsequentValue"

class PropertySpec: QuickSpec {
	override func spec() {
		describe("ConstantProperty") {
			it("should have the value given at initialization") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				expect(constantProperty.value).to(equal(initialPropertyValue))
			}

			it("should yield a producer that sends the current value then completes") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				var sentValue: String?
				var signalCompleted = false

				constantProperty.producer.start(next: { value in
					sentValue = value
				}, completed: {
					signalCompleted = true
				})

				expect(sentValue).to(equal(initialPropertyValue))
				expect(signalCompleted).to(beTruthy())
			}
		}

		describe("MutableProperty") {
			it("should have the value given at initialization") {
				let mutableProperty = MutableProperty(initialPropertyValue)

				expect(mutableProperty.value).to(equal(initialPropertyValue))
			}

			it("should yield a producer that sends the current value then all changes") {
				let mutableProperty = MutableProperty(initialPropertyValue)

				var sentValue: String?

				mutableProperty.producer.start(next: { value in
					sentValue = value
				})

				expect(sentValue).to(equal(initialPropertyValue))
				mutableProperty.value = subsequentPropertyValue
				expect(sentValue).to(equal(subsequentPropertyValue))
			}

			it("should complete its producer when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)

				var signalCompleted = false

				mutableProperty?.producer.start(completed: {
					signalCompleted = true
				})

				mutableProperty = nil
				expect(signalCompleted).to(beTruthy())
			}
		}

		describe("PropertyOf") {
			it("should pass through behaviors of the input property") {
				let constantProperty = ConstantProperty(initialPropertyValue)
				let propertyOf = PropertyOf(constantProperty)

				var sentValue: String?
				var producerCompleted = false

				propertyOf.producer.start(next: { value in
					sentValue = value
				}, completed: {
					producerCompleted = true
				})

				expect(sentValue).to(equal(initialPropertyValue))
				expect(producerCompleted).to(beTruthy())
			}
		}

		describe("DynamicProperty") {
			var object: ObservableObject!
			var property: DynamicProperty!

			let propertyValue: () -> Int? = {
				if let value: AnyObject = property?.value {
					return value as? Int
				} else {
					return nil
				}
			}

			beforeEach {
				object = ObservableObject()
				expect(object.rac_value).to(equal(0))

				property = DynamicProperty(object: object, keyPath: "rac_value")
			}

			afterEach {
				object = nil
			}

			it("should read the underlying object") {
				expect(propertyValue()).to(equal(0))

				object.rac_value = 1
				expect(propertyValue()).to(equal(1))
			}

			it("should write the underlying object") {
				property.value = 1
				expect(object.rac_value).to(equal(1))
				expect(propertyValue()).to(equal(1))
			}

			it("should observe changes to the property and underlying object") {
				var values: [Int] = []
				property.producer.start(next: { value in
					expect(value).notTo(beNil())
					values.append((value as? Int) ?? -1)
				})

				expect(values).to(equal([ 0 ]))

				property.value = 1
				expect(values).to(equal([ 0, 1 ]))

				object.rac_value = 2
				expect(values).to(equal([ 0, 1, 2 ]))
			}

			it("should complete when the underlying object deallocates") {
				var completed = false

				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = DynamicProperty(object: object, keyPath: "rac_value")

					property.producer.start(completed: {
						completed = true
					})

					expect(completed).to(beFalsy())
					expect(property.value).notTo(beNil())
					return property
				}()

				expect(completed).toEventually(beTruthy())
				expect(property.value).to(beNil())
			}
		}

		describe("binding") {
			describe("from a Signal") {
				it("should update the property with values sent from the signal") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signal

					// Verify that the binding hasn't changed the property value:
					expect(mutableProperty.value).to(equal(initialPropertyValue))

					sendNext(observer, subsequentPropertyValue)
					expect(mutableProperty.value).to(equal(subsequentPropertyValue))
				}

				it("should tear down the binding when disposed") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty <~ signal
					bindingDisposable.dispose()

					sendNext(observer, subsequentPropertyValue)
					expect(mutableProperty.value).to(equal(initialPropertyValue))
				}
				
				it("should retain property by binding"){
					let (signal, _) = Signal<AnyObject?, NoError>.pipe()
					var property: DynamicProperty!
					weak var dynamicProperty: DynamicProperty?
					var object = ObservableObject()
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					property = nil
					expect(dynamicProperty).to(beNil())
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					dynamicProperty! <~ signal // binding
					property = nil
					expect(dynamicProperty).toNot(beNil())
				}
				
				it("should release property and tear down the binding when binding signal is completed"){
					let (signal, observer) = Signal<AnyObject?, NoError>.pipe()
					var property: DynamicProperty!
					weak var dynamicProperty: DynamicProperty?
					var object = ObservableObject()
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					let bindingDisposable = dynamicProperty! <~ signal
					property = nil
					
					expect(dynamicProperty).toNot(beNil())
					expect(bindingDisposable.disposed).to(beFalsy())
					
					sendCompleted(observer)
					expect(dynamicProperty).to(beNil())
					expect(bindingDisposable.disposed).to(beTruthy())
				}
				
				it("should release property and tear down the binding when property's Value is deallocated (only DynamicProperty)"){
					let (signal, _) = Signal<AnyObject?, NoError>.pipe()
					var property: DynamicProperty!
					weak var dynamicProperty: DynamicProperty?
					var object: ObservableObject! = ObservableObject()
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					let bindingDisposable = dynamicProperty! <~ signal
					property = nil
					
					expect(dynamicProperty).toNot(beNil())
					expect(bindingDisposable.disposed).to(beFalsy())
					
					object = nil
					expect(dynamicProperty).to(beNil())
					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}

			describe("from a SignalProducer") {
				it("should start a signal and update the property with its values") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signalProducer

					expect(mutableProperty.value).to(equal(signalValues.last!))
				}

				it("should tear down the binding when disposed") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)

					let disposable = mutableProperty <~ signalProducer

					disposable.dispose()
					// TODO: Assert binding was teared-down?
				}
				
				it("should retain property by binding"){
					let (signalProducer, _) = SignalProducer<Int, NoError>.buffer(1)
					var property: DynamicProperty!
					weak var dynamicProperty: DynamicProperty?
					var object: ObservableObject! = ObservableObject()
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					property = nil
					expect(dynamicProperty).to(beNil())
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					dynamicProperty! <~ signalProducer
					property = nil
					expect(dynamicProperty).toNot(beNil())
				}
				
				it("should release property and tear down the binding when binding signal is completed"){
					let (signalProducer, observer) = SignalProducer<Int, NoError>.buffer(1)
					var property: DynamicProperty!
					weak var dynamicProperty: DynamicProperty?
					var object: ObservableObject! = ObservableObject()
					
					property = DynamicProperty(object: object, keyPath: "rac_value")
					dynamicProperty = property
					let bindingDisposable = dynamicProperty! <~ signalProducer
					property = nil
					
					expect(dynamicProperty).toNot(beNil())
					expect(bindingDisposable.disposed).to(beFalsy())
					
					sendCompleted(observer)
					expect(dynamicProperty).to(beNil())
					expect(bindingDisposable.disposed).to(beTruthy())
				}

				pending("should release property and tear down the binding when property's Value is deallocated"){}
			}

			describe("from another property") {
				it("should take the source property's current value") {
					let sourceProperty = ConstantProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					expect(destinationProperty.value).to(equal(initialPropertyValue))
				}

				it("should update with changes to the source property's value") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					destinationProperty.value = subsequentPropertyValue
					expect(destinationProperty.value).to(equal(subsequentPropertyValue))
				}

				it("should tear down the binding when disposed") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					let bindingDisposable = destinationProperty <~ sourceProperty.producer
					bindingDisposable.dispose()

					sourceProperty.value = subsequentPropertyValue

					expect(destinationProperty.value).to(equal(initialPropertyValue))
				}

				it("should tear down the binding when the source property deallocates") {
					var sourceProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					let bindingDisposable = destinationProperty <~ sourceProperty!.producer

					sourceProperty = nil

					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}
		}
	}
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
}
