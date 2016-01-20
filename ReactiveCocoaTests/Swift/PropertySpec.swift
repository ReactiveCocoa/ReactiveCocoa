//
//  PropertySpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

private let initialPropertyValue = "InitialValue"
private let subsequentPropertyValue = "SubsequentValue"
private let finalPropertyValue = "FinalValue"

class PropertySpec: QuickSpec {
	override func spec() {
		describe("ConstantProperty") {
			it("should have the value given at initialization") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				expect(constantProperty.value) == initialPropertyValue
			}

			it("should yield a signal that interrupts observers without emitting any value.") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				var signalInterrupted = false
				var hasUnexpectedEventsEmitted = false

				constantProperty.signal.observe { event in
					switch event {
					case .Interrupted:
						signalInterrupted = true
					case .Next, .Failed, .Completed:
						hasUnexpectedEventsEmitted = true
					}
				}

				expect(signalInterrupted) == true
				expect(hasUnexpectedEventsEmitted) == false
			}

			it("should yield a producer that sends the current value then completes") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				var sentValue: String?
				var signalCompleted = false

				constantProperty.producer.start { event in
					switch event {
					case let .Next(value):
						sentValue = value
					case .Completed:
						signalCompleted = true
					default:
						break
					}
				}

				expect(sentValue) == initialPropertyValue
				expect(signalCompleted) == true
			}
		}

		describe("MutableProperty") {
			it("should have the value given at initialization") {
				let mutableProperty = MutableProperty(initialPropertyValue)

				expect(mutableProperty.value) == initialPropertyValue
			}

			it("should yield a producer that sends the current value then all changes") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var sentValue: String?

				mutableProperty.producer.startWithNext { sentValue = $0 }

				expect(sentValue) == initialPropertyValue

				mutableProperty.value = subsequentPropertyValue
				expect(sentValue) == subsequentPropertyValue

				mutableProperty.value = finalPropertyValue
				expect(sentValue) == finalPropertyValue
			}

			it("should yield a producer that sends the current value then all changes, even if the value actually remains unchanged") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var count = 0

				mutableProperty.producer.startWithNext { _ in count = count + 1 }

				expect(count) == 1

				mutableProperty.value = initialPropertyValue
				expect(count) == 2

				mutableProperty.value = initialPropertyValue
				expect(count) == 3
			}

			it("should yield a signal that emits subsequent changes to the value") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var sentValue: String?

				mutableProperty.signal.observeNext { sentValue = $0 }

				expect(sentValue).to(beNil())

				mutableProperty.value = subsequentPropertyValue
				expect(sentValue) == subsequentPropertyValue

				mutableProperty.value = finalPropertyValue
				expect(sentValue) == finalPropertyValue
			}

			it("should yield a signal that emits subsequent changes to the value, even if the value actually remains unchanged") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var count = 0

				mutableProperty.signal.observeNext { _ in count = count + 1 }

				expect(count) == 0

				mutableProperty.value = initialPropertyValue
				expect(count) == 1

				mutableProperty.value = initialPropertyValue
				expect(count) == 2
			}

			it("should complete its producer when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)
				var producerCompleted = false

				mutableProperty!.producer.startWithCompleted { producerCompleted = true }

				mutableProperty = nil
				expect(producerCompleted) == true
			}

			it("should complete its signal when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)
				var signalCompleted = false

				mutableProperty!.signal.observeCompleted { signalCompleted = true }

				mutableProperty = nil
				expect(signalCompleted) == true
			}

			it("should modify the value atomically") {
				let property = MutableProperty(initialPropertyValue)

				expect(property.modify({ _ in subsequentPropertyValue })) == initialPropertyValue
				expect(property.value) == subsequentPropertyValue
			}

			it("should modify the value atomically and subsquently send out a Next event with the new value") {
				let property = MutableProperty(initialPropertyValue)
				var value: String?

				property.producer.startWithNext {
					value = $0
				}

				expect(value) == initialPropertyValue
				expect(property.modify({ _ in subsequentPropertyValue })) == initialPropertyValue

				expect(property.value) == subsequentPropertyValue
				expect(value) == subsequentPropertyValue
			}

			it("should swap the value atomically") {
				let property = MutableProperty(initialPropertyValue)

				expect(property.swap(subsequentPropertyValue)) == initialPropertyValue
				expect(property.value) == subsequentPropertyValue
			}

			it("should swap the value atomically and subsquently send out a Next event with the new value") {
				let property = MutableProperty(initialPropertyValue)
				var value: String?

				property.producer.startWithNext {
					value = $0
				}

				expect(value) == initialPropertyValue
				expect(property.swap(subsequentPropertyValue)) == initialPropertyValue

				expect(property.value) == subsequentPropertyValue
				expect(value) == subsequentPropertyValue
			}

			it("should perform an action with the value") {
				let property = MutableProperty(initialPropertyValue)

				let result: Bool = property.withValue { $0.isEmpty }

				expect(result) == false
				expect(property.value) == initialPropertyValue
			}

			it("should not deadlock on recursive value access") {
				let (producer, observer) = SignalProducer<Int, NoError>.buffer(1)
				let property = MutableProperty(0)
				var value: Int?

				property <~ producer
				property.producer.startWithNext { _ in
					value = property.value
				}

				observer.sendNext(10)
				expect(value) == 10
			}

			it("should not deadlock on recursive value access with a closure") {
				let (producer, observer) = SignalProducer<Int, NoError>.buffer(1)
				let property = MutableProperty(0)
				var value: Int?

				property <~ producer
				property.producer.startWithNext { _ in
					value = property.withValue { $0 + 1 }
				}

				observer.sendNext(10)
				expect(value) == 11
			}

			it("should not deadlock on recursive observation") {
				let property = MutableProperty(0)

				var value: Int?
				property.producer.startWithNext { _ in
					property.producer.startWithNext { x in value = x }
				}

				expect(value) == 0

				property.value = 1
				expect(value) == 1
			}
		}

		describe("AnyProperty") {
			describe("from a PropertyType") {
				it("should pass through behaviors of the input property") {
					let constantProperty = ConstantProperty(initialPropertyValue)
					let property = AnyProperty(constantProperty)

					var sentValue: String?
					var signalSentValue: String?
					var producerCompleted = false
					var signalInterrupted = false

					property.producer.start { event in
						switch event {
						case let .Next(value):
							sentValue = value
						case .Completed:
							producerCompleted = true
						default:
							break
						}
					}

					property.signal.observe { event in
						switch event {
						case let .Next(value):
							signalSentValue = value
						case .Interrupted:
							signalInterrupted = true
						default:
							break
						}
					}

					expect(sentValue) == initialPropertyValue
					expect(signalSentValue).to(beNil())
					expect(producerCompleted) == true
					expect(signalInterrupted) == true
				}
			}
			
			describe("from a value and SignalProducer") {
				it("should initially take on the supplied value") {
					let property = AnyProperty(
						initialValue: initialPropertyValue,
						producer: SignalProducer.never)
					
					expect(property.value) == initialPropertyValue
				}
				
				it("should take on each value sent on the producer") {
					let property = AnyProperty(
						initialValue: initialPropertyValue,
						producer: SignalProducer(value: subsequentPropertyValue))
					
					expect(property.value) == subsequentPropertyValue
				}
			}
			
			describe("from a value and Signal") {
				it("should initially take on the supplied value, then values sent on the signal") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let property = AnyProperty(
						initialValue: initialPropertyValue,
						signal: signal)
					
					expect(property.value) == initialPropertyValue
					
					observer.sendNext(subsequentPropertyValue)
					
					expect(property.value) == subsequentPropertyValue
				}
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
				expect(object.rac_value) == 0

				property = DynamicProperty(object: object, keyPath: "rac_value")
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
					values.append(value as! Int)
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
					values.append(value as! Int)
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
					values.append(value as! Int)
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
					values.append(value as! Int)
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
					let property = DynamicProperty(object: object, keyPath: "rac_value")

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
					let property = DynamicProperty(object: object, keyPath: "rac_value")

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

			it("should retain property while DynamicProperty's underlying object is retained"){
				weak var dynamicProperty: DynamicProperty? = property
				
				property = nil
				expect(dynamicProperty).toNot(beNil())
				
				object = nil
				expect(dynamicProperty).to(beNil())
			}
		}

		describe("binding") {
			describe("from a Signal") {
				it("should update the property with values sent from the signal") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signal

					// Verify that the binding hasn't changed the property value:
					expect(mutableProperty.value) == initialPropertyValue

					observer.sendNext(subsequentPropertyValue)
					expect(mutableProperty.value) == subsequentPropertyValue
				}

				it("should tear down the binding when disposed") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty <~ signal
					bindingDisposable.dispose()

					observer.sendNext(subsequentPropertyValue)
					expect(mutableProperty.value) == initialPropertyValue
				}
				
				it("should tear down the binding when bound signal is completed") {
					let (signal, observer) = Signal<String, NoError>.pipe()
					
					let mutableProperty = MutableProperty(initialPropertyValue)
					
					let bindingDisposable = mutableProperty <~ signal
					
					expect(bindingDisposable.disposed) == false
					observer.sendCompleted()
					expect(bindingDisposable.disposed) == true
				}
				
				it("should tear down the binding when the property deallocates") {
					let (signal, _) = Signal<String, NoError>.pipe()

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty! <~ signal

					mutableProperty = nil
					expect(bindingDisposable.disposed) == true
				}
			}

			describe("from a SignalProducer") {
				it("should start a signal and update the property with its values") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signalProducer

					expect(mutableProperty.value) == signalValues.last!
				}

				it("should tear down the binding when disposed") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)
					let disposable = mutableProperty <~ signalProducer

					disposable.dispose()
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when bound signal is completed") {
					let (signalProducer, observer) = SignalProducer<String, NoError>.buffer(1)
					
					let mutableProperty = MutableProperty(initialPropertyValue)
					mutableProperty <~ signalProducer

					observer.sendCompleted()
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the property deallocates") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)
					let disposable = mutableProperty! <~ signalProducer

					mutableProperty = nil
					expect(disposable.disposed) == true
				}
			}

			describe("from another property") {
				it("should take the source property's current value") {
					let sourceProperty = ConstantProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					expect(destinationProperty.value) == initialPropertyValue
				}

				it("should update with changes to the source property's value") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					sourceProperty.value = subsequentPropertyValue
					expect(destinationProperty.value) == subsequentPropertyValue
				}

				it("should tear down the binding when disposed") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					let bindingDisposable = destinationProperty <~ sourceProperty.producer
					bindingDisposable.dispose()

					sourceProperty.value = subsequentPropertyValue

					expect(destinationProperty.value) == initialPropertyValue
				}

				it("should tear down the binding when the source property deallocates") {
					var sourceProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")
					destinationProperty <~ sourceProperty!.producer

					sourceProperty = nil
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the destination property deallocates") {
					let sourceProperty = MutableProperty(initialPropertyValue)
					var destinationProperty: MutableProperty<String>? = MutableProperty("")

					let bindingDisposable = destinationProperty! <~ sourceProperty.producer
					destinationProperty = nil

					expect(bindingDisposable.disposed) == true
				}
			}
		}
	}
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
}
