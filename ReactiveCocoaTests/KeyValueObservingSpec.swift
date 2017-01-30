import Foundation
@testable import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble

class KeyValueObservingSpec: QuickSpec {
	override func spec() {
		describe("NSObject.valuesForKeyPath") {
			it("should sends the current value and then the changes for the key path") {
				let object = ObservableObject()
				var values: [Int] = []

				object.reactive
					.values(forKeyPath: #keyPath(ObservableObject.rac_value))
					.startWithValues { value in
						expect(value).notTo(beNil())
						values.append(value as! Int)
					}

				expect(values) == [ 0 ]

				object.rac_value = 1
				expect(values) == [ 0, 1 ]

				object.rac_value = 2
				expect(values) == [ 0, 1, 2 ]
			}

			it("should sends the current value and then the changes for the key path, even if the value actually remains unchanged") {
				let object = ObservableObject()
				var values: [Int] = []

				object.reactive
					.values(forKeyPath: #keyPath(ObservableObject.rac_value))
					.startWithValues { value in
						expect(value).notTo(beNil())
						values.append(value as! Int)
					}

				expect(values) == [ 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0 ]

				object.rac_value = 0
				expect(values) == [ 0, 0, 0 ]
			}

			it("should complete when the object deallocates") {
				var completed = false

				_ = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()

					object.reactive
						.values(forKeyPath: #keyPath(ObservableObject.rac_value))
						.startWithCompleted { completed = true }

					expect(completed) == false
				}()

				expect(completed).toEventually(beTruthy())
			}

			it("should interrupt") {
				var interrupted = false

				let object = ObservableObject()
				let disposable = object.reactive
					.values(forKeyPath: #keyPath(ObservableObject.rac_value))
					.startWithInterrupted { interrupted = true }

				expect(interrupted) == false

				disposable.dispose()
				expect(interrupted) == true
			}

			it("should observe changes in a nested key path") {
				let parentObject = NestedObservableObject()
				var values: [Int] = []

				parentObject
					.reactive
					.values(forKeyPath: #keyPath(NestedObservableObject.rac_object.rac_value))
					.map { $0 as! NSNumber }
					.map { $0.intValue }
					.startWithValues {
						values.append($0)
					}

				expect(values) == [0]

				parentObject.rac_object.rac_value = 1
				expect(values) == [0, 1]

				let oldInnerObject = parentObject.rac_object

				let newInnerObject = ObservableObject()
				parentObject.rac_object = newInnerObject
				expect(values) == [0, 1, 0]

				parentObject.rac_object.rac_value = 10
				oldInnerObject.rac_value = 2
				expect(values) == [0, 1, 0, 10]
			}

			it("should observe changes in a nested weak key path") {
				let parentObject = NestedObservableObject()
				var innerObject = Optional(ObservableObject())
				parentObject.rac_weakObject = innerObject

				// `#keyPath` does not work with weak relationships.

				var values: [Int] = []
				parentObject
					.reactive
					.values(forKeyPath: "rac_weakObject.rac_value")
					.map { $0 as! NSNumber }
					.map { $0.intValue }
					.startWithValues {
						values.append($0)
					}

				expect(values) == [0]

				innerObject?.rac_value = 1
				expect(values) == [0, 1]

				autoreleasepool {
					innerObject = nil
				}

				expect(values) == [0, 1]

				innerObject = ObservableObject()
				parentObject.rac_weakObject = innerObject
				expect(values) == [0, 1, 0]

				innerObject?.rac_value = 10
				expect(values) == [0, 1, 0, 10]
			}

			it("should not retain replaced value in a nested key path") {
				let parentObject = NestedObservableObject()

				weak var weakOriginalInner: ObservableObject? = parentObject.rac_object
				expect(weakOriginalInner).toNot(beNil())

				parentObject.rac_object = ObservableObject()
				expect(weakOriginalInner).to(beNil())
			}

			it("should not crash an Operation") {
				// Related issue:
				// https://github.com/ReactiveCocoa/ReactiveCocoa/issues/3329
				func invoke() {
					let op = Operation()
					op.reactive.values(forKeyPath: "isFinished").start()
				}

				invoke()
			}

			describe("thread safety") {
				var testObject: ObservableObject!
				var concurrentQueue: DispatchQueue!

				beforeEach {
					testObject = ObservableObject()
					concurrentQueue = DispatchQueue(label: "org.reactivecocoa.ReactiveCocoa.DynamicPropertySpec.concurrentQueue",
					                                attributes: .concurrent)
				}

				it("should handle changes being made on another queue") {
					var observedValue = 0

					testObject
						.reactive
						.values(forKeyPath: #keyPath(ObservableObject.rac_value))
						.skip(first: 1)
						.take(first: 1)
						.map { $0 as! NSNumber }
						.map { $0.intValue }
						.startWithValues {
							observedValue = $0
						}

					concurrentQueue.async {
						testObject.rac_value = 2
					}

					concurrentQueue.sync(flags: .barrier) {}
					expect(observedValue).toEventually(equal(2))
				}

				it("should handle changes being made on another queue using deliverOn") {
					var observedValue = 0

					testObject
						.reactive
						.values(forKeyPath: #keyPath(ObservableObject.rac_value))
						.skip(first: 1)
						.take(first: 1)
						.observe(on: UIScheduler())
						.map { $0 as! NSNumber }
						.map { $0.intValue }
						.startWithValues {
							observedValue = $0
						}

					concurrentQueue.async {
						testObject.rac_value = 2
					}

					concurrentQueue.sync(flags: .barrier) {}
					expect(observedValue).toEventually(equal(2))
				}

				it("async disposal of target") {
					var observedValue = 0

					testObject
						.reactive
						.values(forKeyPath: #keyPath(ObservableObject.rac_value))
						.observe(on: UIScheduler())
						.map { $0 as! NSNumber }
						.map { $0.intValue }
						.startWithValues {
							observedValue = $0
						}

					concurrentQueue.async {
						testObject.rac_value = 2
						testObject = nil
					}

					concurrentQueue.sync(flags: .barrier) {}
					expect(observedValue).toEventually(equal(2))
				}
			}

			describe("stress tests") {
				let numIterations = 5000

				var testObject: ObservableObject!
				var iterationQueue: DispatchQueue!
				var concurrentQueue: DispatchQueue!

				beforeEach {
					testObject = ObservableObject()
					iterationQueue = DispatchQueue(label: "org.reactivecocoa.ReactiveCocoa.RACKVOProxySpec.iterationQueue",
					                               attributes: .concurrent)
					concurrentQueue = DispatchQueue(label: "org.reactivecocoa.ReactiveCocoa.DynamicPropertySpec.concurrentQueue",
					                                attributes: .concurrent)
				}

				it("attach observers") {
					let deliveringObserver: QueueScheduler
					if #available(*, OSX 10.10) {
						deliveringObserver = QueueScheduler(name: "\(#file):\(#line)")
					} else {
						deliveringObserver = QueueScheduler(queue: DispatchQueue(label: "\(#file):\(#line)"))
					}

					var atomicCounter = Int64(0)

					DispatchQueue.concurrentPerform(iterations: numIterations) { index in
						testObject
							.reactive
							.values(forKeyPath: #keyPath(ObservableObject.rac_value))
							.skip(first: 1)
							.observe(on: deliveringObserver)
							.map { $0 as! NSNumber }
							.map { $0.int64Value }
							.startWithValues { value in
								OSAtomicAdd64(value, &atomicCounter)
							}
					}

					testObject.rac_value = 2

					expect(atomicCounter).toEventually(equal(10000), timeout: 30.0)
				}

				// ReactiveCocoa/ReactiveCocoa#1122
				it("async disposal of observer") {
					let serialDisposable = SerialDisposable()

					iterationQueue.async {
						DispatchQueue.concurrentPerform(iterations: numIterations) { index in
							let disposable = testObject.reactive
								.values(forKeyPath: #keyPath(ObservableObject.rac_value))
								.startWithCompleted {}

							serialDisposable.inner = disposable

							concurrentQueue.async {
								testObject.rac_value = index
							}
						}
					}

					iterationQueue.sync(flags: .barrier) {
						serialDisposable.dispose()
					}
				}

				it("async disposal of signal with in-flight changes") {
					let otherScheduler: QueueScheduler

					var token = Optional(Lifetime.Token())
					let lifetime = Lifetime(token!)

					if #available(*, OSX 10.10) {
						otherScheduler = QueueScheduler(name: "\(#file):\(#line)")
					} else {
						otherScheduler = QueueScheduler(queue: DispatchQueue(label: "\(#file):\(#line)"))
					}

					let replayProducer = testObject.reactive
							.values(forKeyPath: #keyPath(ObservableObject.rac_value))
							.map { $0 as! NSNumber }
							.map { $0.intValue }
							.map { $0 % 2 == 0 }
							.observe(on: otherScheduler)
							.take(during: lifetime)
							.replayLazily(upTo: 1)

					replayProducer.start()

					iterationQueue.suspend()

					let half = numIterations / 2

					for index in 0 ..< numIterations {
						iterationQueue.async {
							testObject.rac_value = index
						}

						if index == half {
							iterationQueue.async(flags: .barrier) {
								token = nil
								expect(replayProducer.last()).toNot(beNil())
							}
						}
					}

					iterationQueue.resume()
					iterationQueue.sync(flags: .barrier, execute: {})
				}
			}
		}

		describe("property type and attribute query") {
			let object = TestAttributeQueryObject()

			it("should be able to classify weak references") {
				"weakProperty".withCString { cString in
					let propertyPointer = class_getProperty(type(of: object), cString)
					expect(propertyPointer) != nil

					if let pointer = propertyPointer {
						let attributes = PropertyAttributes(property: pointer)
						expect(attributes.isWeak) == true
						expect(attributes.isObject) == true
						expect(attributes.isBlock) == false
						expect(attributes.objectClass).to(beIdenticalTo(NSObject.self))
					}
				}
			}

			it("should be able to classify blocks") {
				"block".withCString { cString in
					let propertyPointer = class_getProperty(type(of: object), cString)
					expect(propertyPointer) != nil

					if let pointer = propertyPointer {
						let attributes = PropertyAttributes(property: pointer)
						expect(attributes.isWeak) == false
						expect(attributes.isObject) == true
						expect(attributes.isBlock) == true
						expect(attributes.objectClass).to(beNil())
					}
				}
			}

			it("should be able to classify non object properties") {
				"integer".withCString { cString in
					let propertyPointer = class_getProperty(type(of: object), cString)
					expect(propertyPointer) != nil

					if let pointer = propertyPointer {
						let attributes = PropertyAttributes(property: pointer)
						expect(attributes.isWeak) == false
						expect(attributes.isObject) == false
						expect(attributes.isBlock) == false
						expect(attributes.objectClass).to(beNil())
					}
				}
			}
		}
	}
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
}

private class NestedObservableObject: NSObject {
	dynamic var rac_object: ObservableObject = ObservableObject()
	dynamic weak var rac_weakObject: ObservableObject?
}

private class TestAttributeQueryObject: NSObject {
	@objc weak var weakProperty: NSObject? = nil
	@objc var block: @convention(block) (NSObject) -> NSObject? = { _ in nil }
	@objc let integer = 0
}
