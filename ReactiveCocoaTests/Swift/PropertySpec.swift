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

private let initialOtherPropertyValue = "InitialOtherValue"
private let subsequentOtherPropertyValue = "SubsequentOtherValue"
private let finalOtherPropertyValue = "FinalOtherValue"

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
					case .Failed, .Interrupted:
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

			it("should yield a producer which emits the latest value and complete even if the property is deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)
				let producer = mutableProperty!.producer

				var producerCompleted = false
				var hasUnanticipatedEvent = false
				var latestValue = mutableProperty?.value

				mutableProperty!.value = subsequentPropertyValue
				mutableProperty = nil

				producer.start { event in
					switch event {
					case let .Next(value):
						latestValue = value
					case .Completed:
						producerCompleted = true
					case .Interrupted, .Failed:
						hasUnanticipatedEvent = true
					}
				}

				expect(hasUnanticipatedEvent) == false
				expect(producerCompleted) == true
				expect(latestValue) == subsequentPropertyValue
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
				let (producer, observer) = SignalProducer<Int, NoError>.pipe()
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
				let (producer, observer) = SignalProducer<Int, NoError>.pipe()
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

			it("should not deadlock on recursive ABA observation") {
				let propertyA = MutableProperty(0)
				let propertyB = MutableProperty(0)

				var value: Int?
				propertyA.producer.startWithNext { _ in
					propertyB.producer.startWithNext { _ in
						propertyA.producer.startWithNext { x in value = x }
					}
				}

				expect(value) == 0

				propertyA.value = 1
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
						case .Failed, .Interrupted:
							break
						}
					}

					property.signal.observe { event in
						switch event {
						case let .Next(value):
							signalSentValue = value
						case .Interrupted:
							signalInterrupted = true
						case .Failed, .Completed:
							break
						}
					}

					expect(sentValue) == initialPropertyValue
					expect(signalSentValue).to(beNil())
					expect(producerCompleted) == true
					expect(signalInterrupted) == true
				}

				describe("transformed properties") {
					it("should have the latest value available before sending any value") {
						var latestValue: Int!

						let property = MutableProperty(1)
						let mappedProperty = property.map { $0 + 1 }
						mappedProperty.producer.startWithNext { _ in latestValue = mappedProperty.value }

						expect(latestValue) == 2

						property.value = 2
						expect(latestValue) == 3

						property.value = 3
						expect(latestValue) == 4
					}

					it("should retain its source property") {
						var property = Optional(MutableProperty(1))
						weak var weakProperty = property

						var firstMappedProperty = Optional(property!.map { $0 + 1 })
						var secondMappedProperty = Optional(firstMappedProperty!.map { $0 + 2 })
						_ = secondMappedProperty

						property = nil
						expect(weakProperty).toNot(beNil())

						firstMappedProperty = nil
						expect(weakProperty).toNot(beNil())

						secondMappedProperty = nil
						expect(weakProperty).to(beNil())
					}

					describe("signal lifetime and producer lifetime") {
						it("should return a producer and a signal which respect the lifetime of the source property instead of the read-only view itself") {
							var signalCompleted = 0
							var producerCompleted = 0

							var property = Optional(MutableProperty(1))
							var firstMappedProperty = Optional(property!.map { $0 + 1 })
							var secondMappedProperty = Optional(firstMappedProperty!.map { $0 + 2 })
							var thirdMappedProperty = Optional(secondMappedProperty!.map { $0 + 2 })

							firstMappedProperty!.signal.observeCompleted { signalCompleted += 1	}
							secondMappedProperty!.signal.observeCompleted { signalCompleted += 1	}
							thirdMappedProperty!.signal.observeCompleted { signalCompleted += 1	}

							firstMappedProperty!.producer.startWithCompleted { producerCompleted += 1	}
							secondMappedProperty!.producer.startWithCompleted { producerCompleted += 1	}
							thirdMappedProperty!.producer.startWithCompleted { producerCompleted += 1	}

							firstMappedProperty = nil
							expect(signalCompleted) == 0
							expect(producerCompleted) == 0

							secondMappedProperty = nil
							expect(signalCompleted) == 0
							expect(producerCompleted) == 0

							property = nil
							expect(signalCompleted) == 0
							expect(producerCompleted) == 0

							thirdMappedProperty = nil
							expect(signalCompleted) == 3
							expect(producerCompleted) == 3
						}
					}
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

		describe("PropertyType") {
			describe("map") {
				it("should transform the current value and all subsequent values") {
					let property = MutableProperty(1)
					let mappedProperty = property
						.map { $0 + 1 }
					expect(mappedProperty.value) == 2

					property.value = 2
					expect(mappedProperty.value) == 3
				}
			}

			describe("combineLatest") {
				var property: MutableProperty<String>!
				var otherProperty: MutableProperty<String>!

				beforeEach {
					property = MutableProperty(initialPropertyValue)
					otherProperty = MutableProperty(initialOtherPropertyValue)
				}

				it("should forward the latest values from both inputs") {
					let combinedProperty = property.combineLatest(with: otherProperty)
					var latest: (String, String)?
					combinedProperty.signal.observeNext { latest = $0 }

					property.value = subsequentPropertyValue
					expect(latest?.0) == subsequentPropertyValue
					expect(latest?.1) == initialOtherPropertyValue

					// is there a better way to test tuples?
					otherProperty.value = subsequentOtherPropertyValue
					expect(latest?.0) == subsequentPropertyValue
					expect(latest?.1) == subsequentOtherPropertyValue

					property.value = finalPropertyValue
					expect(latest?.0) == finalPropertyValue
					expect(latest?.1) == subsequentOtherPropertyValue
				}

				it("should complete when the source properties are deinitialized") {
					var completed = false

					var combinedProperty = Optional(property.combineLatest(with: otherProperty))
					combinedProperty!.signal.observeCompleted { completed = true }

					combinedProperty = nil
					expect(completed) == false

					property = nil
					expect(completed) == false

					otherProperty = nil
					expect(completed) == true
				}
			}

			describe("zip") {
				var property: MutableProperty<String>!
				var otherProperty: MutableProperty<String>!

				beforeEach {
					property = MutableProperty(initialPropertyValue)
					otherProperty = MutableProperty(initialOtherPropertyValue)
				}

				it("should combine pairs") {
					var result: [String] = []

					let zippedProperty = property.zip(with: otherProperty)
					zippedProperty.producer.startWithNext { (left, right) in result.append("\(left)\(right)") }

					let firstResult = [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]
					let secondResult = firstResult + [ "\(subsequentPropertyValue)\(subsequentOtherPropertyValue)" ]
					let thirdResult = secondResult + [ "\(finalPropertyValue)\(finalOtherPropertyValue)" ]
					let finalResult = thirdResult + [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]

					expect(result) == firstResult

					property.value = subsequentPropertyValue
					expect(result) == firstResult

					otherProperty.value = subsequentOtherPropertyValue
					expect(result) == secondResult

					property.value = finalPropertyValue
					otherProperty.value = finalOtherPropertyValue
					expect(result) == thirdResult

					property.value = initialPropertyValue
					expect(result) == thirdResult

					property.value = subsequentPropertyValue
					expect(result) == thirdResult

					otherProperty.value = initialOtherPropertyValue
					expect(result) == finalResult
				}

				it("should complete its producer only when the source properties are deinitialized") {
					var result: [String] = []
					var completed = false

					var zippedProperty = Optional(property.zip(with: otherProperty))
					zippedProperty!.producer.start { event in
						switch event {
						case let .Next(left, right):
							result.append("\(left)\(right)")
						case .Completed:
							completed = true
						default:
							break
						}
					}

					expect(completed) == false
					expect(result) == [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]

					property.value = subsequentPropertyValue
					expect(result) == [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]

					zippedProperty = nil
					expect(completed) == false

					property = nil
					otherProperty = nil
					expect(completed) == true
				}
			}

			describe("unary operators") {
				var property: MutableProperty<String>!

				beforeEach {
					property = MutableProperty(initialPropertyValue)
				}

				describe("combinePrevious") {
					it("should pack the current value and the previous value a tuple") {
						let transformedProperty = property.combinePrevious(initialPropertyValue)

						expect(transformedProperty.value.0) == initialPropertyValue
						expect(transformedProperty.value.1) == initialPropertyValue

						property.value = subsequentPropertyValue

						expect(transformedProperty.value.0) == initialPropertyValue
						expect(transformedProperty.value.1) == subsequentPropertyValue

						property.value = finalPropertyValue

						expect(transformedProperty.value.0) == subsequentPropertyValue
						expect(transformedProperty.value.1) == finalPropertyValue
					}

					it("should complete its producer only when the source property is deinitialized") {
						var result: (String, String)?
						var completed = false

						var transformedProperty = Optional(property.combinePrevious(initialPropertyValue))
						transformedProperty!.producer.start { event in
							switch event {
							case let .Next(tuple):
								result = tuple
							case .Completed:
								completed = true
							default:
								break
							}
						}

						expect(result?.0) == initialPropertyValue
						expect(result?.1) == initialPropertyValue

						property.value = subsequentPropertyValue

						expect(result?.0) == initialPropertyValue
						expect(result?.1) == subsequentPropertyValue

						transformedProperty = nil
						expect(completed) == false

						property = nil
						expect(completed) == true
					}
				}

				describe("skipRepeats") {
					it("should not emit events for subsequent equatable values that are the same as the current value") {
						let transformedProperty = property.skipRepeats()

						var counter = 0
						transformedProperty.signal.observeNext { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						property.value = initialPropertyValue
						property.value = initialPropertyValue

						expect(counter) == 0

						property.value = subsequentPropertyValue
						property.value = subsequentPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 1

						property.value = finalPropertyValue
						property.value = initialPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 4
					}

					it("should not emit events for subsequent values that are regarded as the same as the current value by the supplied closure") {
						var counter = 0
						let transformedProperty = property.skipRepeats { _, newValue in newValue == initialPropertyValue }

						transformedProperty.signal.observeNext { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						expect(counter) == 0

						property.value = subsequentPropertyValue
						expect(counter) == 1

						property.value = finalPropertyValue
						expect(counter) == 2

						property.value = initialPropertyValue
						expect(counter) == 2
					}

					it("should complete its producer only when the source property is deinitialized") {
						var counter = 0
						var completed = false

						var transformedProperty = Optional(property.skipRepeats())
						transformedProperty!.producer.start { event in
							switch event {
							case .Next:
								counter += 1
							case .Completed:
								completed = true
							default:
								break
							}
						}

						expect(counter) == 1

						property.value = initialPropertyValue
						expect(counter) == 1

						transformedProperty = nil
						expect(completed) == false

						property = nil
						expect(completed) == true
					}
				}

				describe("uniqueValues") {
					it("should emit hashable values that have not been emited before") {
						let transformedProperty = property.uniqueValues()

						var counter = 0
						transformedProperty.signal.observeNext { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						expect(counter) == 0

						property.value = subsequentPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 1

						property.value = finalPropertyValue
						property.value = initialPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 2
					}

					it("should emit only the values of which the computed identity have not been captured before") {
						let transformedProperty = property.uniqueValues { _ in 0 }

						var counter = 0
						transformedProperty.signal.observeNext { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						property.value = subsequentPropertyValue
						property.value = finalPropertyValue
						expect(counter) == 0
					}

					it("should complete its producer only when the source property is deinitialized") {
						var counter = 0
						var completed = false

						var transformedProperty = Optional(property.uniqueValues())
						transformedProperty!.producer.start { event in
							switch event {
							case .Next:
								counter += 1
							case .Completed:
								completed = true
							default:
								break
							}
						}

						expect(counter) == 1

						property.value = initialPropertyValue
						expect(counter) == 1

						transformedProperty = nil
						expect(completed) == false

						property = nil
						expect(completed) == true
					}
				}
			}

			describe("flattening") {
				describe("flatten") {
					describe("PropertyFlattenStrategy.Latest") {
						it("should forward values from the latest inner property") {
							let firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							var outerProperty = Optional(MutableProperty(firstProperty!))

							var receivedValues: [Int] = []
							var errored = false
							var completed = false

							outerProperty!.flatten(.Latest).producer.start { event in
								switch event {
								case let .Next(value):
									receivedValues.append(value)
								case .Completed:
									completed = true
								case .Failed:
									errored = true
								case .Interrupted:
									break
								}
							}

							expect(receivedValues) == [ 0 ]

							outerProperty!.value = secondProperty!
							secondProperty!.value = 11
							outerProperty!.value = thirdProperty!
							thirdProperty!.value = 21

							expect(receivedValues) == [ 0, 10, 11, 20, 21 ]
							expect(errored) == false
							expect(completed) == false

							secondProperty!.value = 12
							secondProperty = nil
							thirdProperty!.value = 22
							thirdProperty = nil

							expect(receivedValues) == [ 0, 10, 11, 20, 21, 22 ]
							expect(errored) == false
							expect(completed) == false

							outerProperty = nil
							expect(errored) == false
							expect(completed) == true
						}

						it("should release the old properties when switched or deallocated") {
							var firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							weak var weakFirstProperty = firstProperty
							weak var weakSecondProperty = secondProperty
							weak var weakThirdProperty = thirdProperty

							var outerProperty = Optional(MutableProperty(firstProperty!))
							var flattened = Optional(outerProperty!.flatten(.Latest))

							var errored = false
							var completed = false

							flattened!.producer.start { event in
								switch event {
								case .Completed:
									completed = true
								case .Failed:
									errored = true
								case .Interrupted, .Next:
									break
								}
							}

							firstProperty = nil
							outerProperty!.value = secondProperty!
							expect(weakFirstProperty).to(beNil())

							secondProperty = nil
							outerProperty!.value = thirdProperty!
							expect(weakSecondProperty).to(beNil())

							thirdProperty = nil
							outerProperty = nil
							flattened = nil
							expect(weakThirdProperty).to(beNil())
							expect(errored) == false
							expect(completed) == true
						}
					}
				}

				describe("flatMap") {
					describe("PropertyFlattenStrategy.Latest") {
						it("should forward values from the latest inner transformed property") {
							let firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							var outerProperty = Optional(MutableProperty(firstProperty!))

							var receivedValues: [String] = []
							var errored = false
							var completed = false

							outerProperty!.flatMap(.Latest) { $0.map { "\($0)" } }.producer.start { event in
								switch event {
								case let .Next(value):
									receivedValues.append(value)
								case .Completed:
									completed = true
								case .Failed:
									errored = true
								case .Interrupted:
									break
								}
							}
							
							expect(receivedValues) == [ "0" ]
							
							outerProperty!.value = secondProperty!
							secondProperty!.value = 11
							outerProperty!.value = thirdProperty!
							thirdProperty!.value = 21
							
							expect(receivedValues) == [ "0", "10", "11", "20", "21" ]
							expect(errored) == false
							expect(completed) == false
							
							secondProperty!.value = 12
							secondProperty = nil
							thirdProperty!.value = 22
							thirdProperty = nil
							
							expect(receivedValues) == [ "0", "10", "11", "20", "21", "22" ]
							expect(errored) == false
							expect(completed) == false
							
							outerProperty = nil
							expect(errored) == false
							expect(completed) == true
						}
					}
				}
			}
		}

		describe("DynamicProperty") {
			var object: ObservableObject!
			var property: DynamicProperty<Int>!

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

			it("should retain property while DynamicProperty's underlying object is retained"){
				weak var dynamicProperty: DynamicProperty<Int>? = property
				
				property = nil
				expect(dynamicProperty).toNot(beNil())
				
				object = nil
				expect(dynamicProperty).to(beNil())
			}

			it("should support un-bridged reference types") {
				let dynamicProperty = DynamicProperty<UnbridgedObject>(object: object, keyPath: "rac_reference")
				dynamicProperty.value = UnbridgedObject("foo")
				expect(object.rac_reference.value) == "foo"
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
					let (signalProducer, observer) = SignalProducer<String, NoError>.pipe()

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
