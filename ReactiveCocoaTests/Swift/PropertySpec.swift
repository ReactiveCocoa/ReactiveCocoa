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

class PropertySpec: QuickSpec {
	override func spec() {
		describe("ConstantProperty") {
			it("should have the value given at initialization") {
				let propertyValue = "StringValue"
				let constantProperty = ConstantProperty(propertyValue)

				expect(constantProperty.value).to(equal(propertyValue))
			}

			it("should yield a producer that sends the current value then completes") {
				let propertyValue = "StringValue"
				let constantProperty = ConstantProperty(propertyValue)

				var valueSent: String?
				var signalCompleted = false

				constantProperty.producer.start(next: { value in
					valueSent = value
				},
				completed: {
					signalCompleted = true
				})

				expect(valueSent).to(equal(propertyValue))
				expect(signalCompleted).to(beTruthy())
			}
		}

		describe("MutableProperty") {
			it("should have the value given at initialization") {
				let propertyValue = "StringValue"
				let mutableProperty = MutableProperty(propertyValue)

				expect(mutableProperty.value).to(equal(propertyValue))
			}

			it("should yield a producer that sends the current value then all changes") {
				let initialValue = "StringValue"
				let subsequentValue = "NewStringValue"

				let mutableProperty = MutableProperty(initialValue)

				var valueSent: String?
				var signalCompleted = false

				mutableProperty.producer.start(next: { value in
					valueSent = value
				},
				completed: {
					signalCompleted = true
				})

				expect(valueSent).to(equal(initialValue))
				expect(signalCompleted).to(beFalsy())

				mutableProperty.value = subsequentValue

				expect(valueSent).to(equal(subsequentValue))
				expect(signalCompleted).to(beFalsy())
			}

			it("should complete its producer when deallocated") {
				let propertyValue = "StringValue"
				var mutableProperty: MutableProperty? = MutableProperty(propertyValue)

				var signalCompleted = false

				mutableProperty?.producer.start(next: { value in
				},
				completed: {
					signalCompleted = true
				})

				mutableProperty = nil
				expect(signalCompleted).to(beTruthy())
			}
		}

		describe("PropertyOf") {
			it("should pass through behaviors of the input property") {
				let propertyValue = "StringValue"

				let constantProperty = ConstantProperty(propertyValue)
				let propertyOf = PropertyOf(constantProperty)

				var valueSent: String?

				propertyOf.producer.start(next: { value in
					valueSent = value
				})

				expect(valueSent).to(equal(propertyValue))
			}
		}

		describe("binding") {
			describe("from a Signal") {
				it("should update the property with values sent from the signal") {
					let finalPropertyValue = 815
					var signalObserver: SinkOf<Event<Int, NoError>>?

					let sendPropertyUpdate = {
						sendNext(signalObserver!, finalPropertyValue)
					}

					let signal = Signal<Int, NoError>({ observer in
						signalObserver = observer

						return SimpleDisposable()
					})

					let mutableProperty = MutableProperty<Int>(0)

					mutableProperty <~ signal

					sendPropertyUpdate()
					expect(mutableProperty.value).to(equal(finalPropertyValue))
				}

				it("should tear down the binding when disposed") {
					let signalDisposable = SimpleDisposable()

					let signal = Signal<Int, NoError>({ observer in
						return signalDisposable
					})

					let mutableProperty = MutableProperty<Int>(0)

					let bindingDisposable = mutableProperty <~ signal
					bindingDisposable.dispose()

					// This test is failing: disposing the binding isn't disposing the signal, or am I doing something wrong?
					expect(signalDisposable.disposed).to(beTruthy())
				}

				it("should tear down the binding when the property deallocates") {
					let signal = Signal<Int, NoError>({ observer in
						return SimpleDisposable()
					})

					var mutableProperty: MutableProperty<Int>? = MutableProperty(0)

					let bindingDisposable = mutableProperty! <~ signal

					mutableProperty = nil
					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}

			describe("from a SignalProducer") {
				pending("should start a signal and update the property with its values") {
//					let signalValues = [1, 2, 3]
//					let signalProducer = SignalProducer<Int, NoError>(values: signalValues)
//
//					let mutableProperty = MutableProperty<Int>(0)
//
//					mutableProperty <~ signalProducer
//
//					expect(mutableProperty.value).to(equal(signalValues.last!))
				}

				pending("should tear down the binding when disposed") {
//					let signalValues = [1, 2, 3]
//					let signalProducer = SignalProducer<Int, NoError>(values: signalValues)
//
//					let mutableProperty: MutableProperty<Int> = MutableProperty(0)
//
//					let disposable = mutableProperty <~ signalProducer
//
//					disposable.dispose()
//					// TODO: Assert binding was teared-down?
				}

				pending("should tear down the binding when the property deallocates") {
//					let signalValues = [1, 2, 3]
//					let signalProducer = SignalProducer<Int, NoError>(values: signalValues)
//
//					var mutableProperty: MutableProperty<Int>? = MutableProperty(0)
//
//					let disposable = mutableProperty! <~ signalProducer
//
//					mutableProperty = nil
//					expect(disposable.disposed).to(beTruthy())
				}
			}

			describe("from another property") {
				pending("should take the source property's current value") {
//					let sourceValue = "StringValue"
//					let sourceProperty = ConstantProperty(sourceValue)
//
//					let destinationProperty = MutableProperty("")
//
//					destinationProperty <~ sourceProperty.producer
//
//					expect(destinationProperty.value).to(equal(sourceValue))
				}

			pending("should update with changes to the source property's value") {
//					let sourceInitialValue = "StringValue"
//					let sourceFinalValue = "NewValue"
//
//					let sourceProperty = MutableProperty(sourceInitialValue)
//
//					let destinationProperty = MutableProperty("")
//
//					destinationProperty <~ sourceProperty.producer
//
//					destinationProperty.value = sourceFinalValue
//					expect(destinationProperty.value).to(equal(sourceFinalValue))
				}

				pending("should tear down the binding when disposed") {
//					let sourceInitialValue = "StringValue"
//					let sourceFinalValue = "NewValue"
//
//					let sourceProperty = MutableProperty(sourceInitialValue)
//
//					let destinationProperty = MutableProperty("")
//
//					let bindingDisposable = destinationProperty <~ sourceProperty.producer
//					bindingDisposable.dispose()
//
//					sourceProperty.value = sourceFinalValue
//
//					expect(destinationProperty.value).to(equal(sourceInitialValue))
				}

				pending("should tear down the binding when the source property deallocates") {
//					let sourcePropertyValue = "StringValue"
//
//					var sourceProperty: MutableProperty<String>? = MutableProperty(sourcePropertyValue)
//
//					let destinationProperty = MutableProperty("")
//
//					let bindingDisposable = destinationProperty <~ sourceProperty!.producer
//
//					sourceProperty = nil
//
//					expect(bindingDisposable.disposed).to(beTruthy())
				}

				pending("should tear down the binding when the destination property deallocates") {
//					let sourcePropertyValue = "StringValue"
//
//					let sourceProperty = MutableProperty(sourcePropertyValue)
//
//					var destinationProperty: MutableProperty<String>? = MutableProperty("")
//
//					let bindingDisposable = destinationProperty! <~ sourceProperty.producer
//
//					destinationProperty = nil
//
//					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}
		}
	}
}
