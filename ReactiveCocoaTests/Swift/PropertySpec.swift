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

				mutableProperty.producer.startWithNext { value in
					sentValue = value
				}

				expect(sentValue).to(equal(initialPropertyValue))
				mutableProperty.value = subsequentPropertyValue
				expect(sentValue).to(equal(subsequentPropertyValue))
			}

			it("should complete its producer when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)

				var signalCompleted = false

				mutableProperty?.producer.startWithCompleted {
					signalCompleted = true
				}

				mutableProperty = nil
				expect(signalCompleted).to(beTruthy())
			}

			it("should not deadlock on recursive value access") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()
				let property = MutableProperty(0)
				var value: Int?

				property <~ producer
				property.producer.startWithNext { _ in
					value = property.value
				}

				sendNext(sink, 10)
				expect(value).to(equal(10))
			}

			it("should not deadlock on recursive observation") {
				let property = MutableProperty(0)

				var value: Int?
				property.producer.startWithNext { _ in
					property.producer.startWithNext { x in value = x }
				}

				expect(value).to(equal(0))

				property.value = 1
				expect(value).to(equal(1))
			}
		}

		describe("PropertyOf") {
			describe("from a PropertyType") {
				it("should pass through behaviors of the input property") {
					let constantProperty = ConstantProperty(initialPropertyValue)
					let propertyOf = PropertyOf(constantProperty)

					var sentValue: String?
					var producerCompleted = false

					propertyOf.producer.start { event in
						switch event {
						case let .Next(value):
							sentValue = value
						case .Completed:
							producerCompleted = true
						default:
							break
						}
					}

					expect(sentValue).to(equal(initialPropertyValue))
					expect(producerCompleted).to(beTruthy())
				}
			}
			
			describe("from a value and SignalProducer") {
				it("should initially take on the supplied value") {
					let property = PropertyOf(
						initialValue: initialPropertyValue,
						producer: SignalProducer.never)
					
					expect(property.value).to(equal(initialPropertyValue))
				}
				
				it("should take on each value sent on the producer") {
					let property = PropertyOf(
						initialValue: initialPropertyValue,
						producer: SignalProducer(value: subsequentPropertyValue))
					
					expect(property.value).to(equal(subsequentPropertyValue))
				}
			}
			
			describe("from a value and Signal") {
				it("should initially take on the supplied value, then values sent on the signal") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let property = PropertyOf(
						initialValue: initialPropertyValue,
						signal: signal)
					
					expect(property.value).to(equal(initialPropertyValue))
					
					sendNext(observer, subsequentPropertyValue)
					
					expect(property.value).to(equal(subsequentPropertyValue))
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
				property.producer.startWithNext { value in
					expect(value).notTo(beNil())
					values.append((value as? Int) ?? -1)
				}

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

					property.producer.startWithCompleted {
						completed = true
					}

					expect(completed).to(beFalsy())
					expect(property.value).notTo(beNil())
					return property
				}()

				expect(completed).toEventually(beTruthy())
				expect(property.value).to(beNil())
			}
			
			it("should retain property while DynamicProperty's object is retained"){
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
				
				it("should tear down the binding when bound signal is completed") {
					let (signal, observer) = Signal<String, NoError>.pipe()
					
					let mutableProperty = MutableProperty(initialPropertyValue)
					
					let bindingDisposable = mutableProperty <~ signal
					
					expect(bindingDisposable.disposed).to(beFalsy())
					sendCompleted(observer)
					expect(bindingDisposable.disposed).to(beTruthy())
				}
				
				it("should tear down the binding when the property deallocates") {
					let (signal, _) = Signal<String, NoError>.pipe()

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty! <~ signal

					mutableProperty = nil
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
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when bound signal is completed") {
					let (signalProducer, observer) = SignalProducer<String, NoError>.buffer(1)
					
					let mutableProperty = MutableProperty(initialPropertyValue)
					mutableProperty <~ signalProducer

					sendCompleted(observer)
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the property deallocates") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)
					let disposable = mutableProperty! <~ signalProducer

					mutableProperty = nil
					expect(disposable.disposed).to(beTruthy())
				}
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

					sourceProperty.value = subsequentPropertyValue
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
					destinationProperty <~ sourceProperty!.producer

					sourceProperty = nil
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the destination property deallocates") {
					let sourceProperty = MutableProperty(initialPropertyValue)
					var destinationProperty: MutableProperty<String>? = MutableProperty("")

					let bindingDisposable = destinationProperty! <~ sourceProperty.producer
					destinationProperty = nil

					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}
		}
	}
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
}
