import Foundation
@testable import ReactiveCocoa
import enum Result.NoError
import Quick
import Nimble

class KeyValueObservingSpec: QuickSpec {
	override func spec() {
		describe("NSObject.valuesForKeyPath") {
			it("should sends the current value and then the changes for the key path") {
				let object = ObservableObject()
				var values: [Int] = []
				object.valuesForKeyPath("rac_value").startWithNext { value in
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
				object.valuesForKeyPath("rac_value").startWithNext { value in
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

					object.valuesForKeyPath("rac_value").startWithCompleted {
						completed = true
					}

					expect(completed) == false
				}()

				expect(completed).toEventually(beTruthy())
			}

			it("should interrupt") {
				var interrupted = false

				let object = ObservableObject()
				let disposable = object.valuesForKeyPath("rac_value")
					.startWithInterrupted { interrupted = true }

				expect(interrupted) == false

				disposable.dispose()
				expect(interrupted) == true
			}

			it("should observe changes in a nested key path") {
				let parentObject = NestedObservableObject()
				var values: [Int] = []

				parentObject.valuesForKeyPath("rac_object.rac_value").startWithNext { wrappedInt in
					values.append((wrappedInt as! NSNumber).integerValue)
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

				var values: [Int] = []
				parentObject.valuesForKeyPath("rac_weakObject.rac_value").startWithNext { wrappedInt in
					values.append((wrappedInt as! NSNumber).integerValue)
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

			describe("thread safety") {
				var testObject: ObservableObject!
				var concurrentQueue: dispatch_queue_t!

				beforeEach {
					testObject = ObservableObject()
					concurrentQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.DynamicPropertySpec.concurrentQueue", DISPATCH_QUEUE_CONCURRENT)
				}

				it("should handle changes being made on another queue") {
					var observedValue = 0

					testObject.valuesForKeyPath("rac_value")
						.skip(1)
						.take(1)
						.startWithNext { wrappedInt in
							observedValue = (wrappedInt as! NSNumber).integerValue;
					}

					dispatch_async(concurrentQueue) {
						testObject.rac_value = 2
					}

					dispatch_barrier_sync(concurrentQueue) {}
					expect(observedValue).toEventually(be(2))
				}

				it("should handle changes being made on another queue using deliverOn") {
					var observedValue = 0

					testObject.valuesForKeyPath("rac_value")
						.skip(1)
						.take(1)
						.observeOn(UIScheduler())
						.startWithNext { wrappedInt in
							observedValue = (wrappedInt as! NSNumber).integerValue;
					}

					dispatch_async(concurrentQueue) {
						testObject.rac_value = 2
					}

					dispatch_barrier_sync(concurrentQueue) {}
					expect(observedValue).toEventually(be(2))
				}

				it("async disposal of target") {
					var observedValue = 0

					testObject.valuesForKeyPath("rac_value")
						.observeOn(UIScheduler())
						.startWithNext { wrappedInt in
							observedValue = (wrappedInt as! NSNumber).integerValue;
					}

					dispatch_async(concurrentQueue) {
						testObject.rac_value = 2
						testObject = nil
					}

					dispatch_barrier_sync(concurrentQueue) {}
					expect(observedValue).toEventually(be(2))
				}
			}

			describe("stress tests") {
				let numIterations = 5000

				var testObject: ObservableObject!
				var iterationQueue: dispatch_queue_t!
				var concurrentQueue: dispatch_queue_t!

				beforeEach {
					testObject = ObservableObject()
					iterationQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACKVOProxySpec.iterationQueue", DISPATCH_QUEUE_CONCURRENT)
					concurrentQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.DynamicPropertySpec.concurrentQueue", DISPATCH_QUEUE_CONCURRENT)
				}

				it("attach observers") {
					let deliveringObserver = QueueScheduler(queue: dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACKVOProxySpec.iterationQueue", DISPATCH_QUEUE_CONCURRENT))
					var atomicCounter = Int64(0)

					dispatch_apply(numIterations, iterationQueue) { index in
						testObject.valuesForKeyPath("rac_value")
							.skip(1)
							.observeOn(deliveringObserver)
							.startWithNext { value in
								OSAtomicAdd64((value as! NSNumber).longLongValue, &atomicCounter)
						}
					}

					dispatch_barrier_async(iterationQueue) {
						testObject.rac_value = 2
					}

					expect(atomicCounter).toEventually(equal(10000), timeout: 30.0)
				}

				// ReactiveCocoa/ReactiveCocoa#1122
				it("async disposal of observer") {
					let serialDisposable = SerialDisposable()

					dispatch_apply(numIterations, iterationQueue) { index in
						let disposable = testObject.valuesForKeyPath("rac_value").startWithCompleted {}
						serialDisposable.innerDisposable = disposable

						dispatch_async(concurrentQueue) {
							testObject.rac_value = index;
						}
					}

					dispatch_barrier_sync(iterationQueue) {
						serialDisposable.dispose()
					}
				}

				it("async disposal of signal with in-flight changes") {
					let (teardown, teardownObserver) = Signal<(), NoError>.pipe()
					let otherScheduler = QueueScheduler(queue: concurrentQueue)

					let replayProducer = testObject.valuesForKeyPath("rac_value")
						.map { wrappedInt in (wrappedInt as! NSNumber).intValue % 2 == 0 }
						.observeOn(otherScheduler)
						.takeUntil(teardown)
						.replayLazily(1)

					replayProducer.start { _ in }

					dispatch_apply(numIterations, iterationQueue) { index in
						testObject.rac_value = index
					}

					dispatch_barrier_async(iterationQueue) {
						teardownObserver.sendNext()
					}

					let event = replayProducer.last()
					expect(event).toNot(beNil())
				}
			}
		}

		describe("property type and attribute query") {
			let object = TestAttributeQueryObject()

			it("should be able to classify weak references") {
				"weakProperty".withCString { cString in
					let propertyPointer = class_getProperty(object.dynamicType, cString)
					expect(propertyPointer) != nil as COpaquePointer

					if propertyPointer != nil {
						let attributes = PropertyAttributes(property: propertyPointer)
						expect(attributes.isWeak) == true
						expect(attributes.isObject) == true
						expect(attributes.isBlock) == false
						expect(attributes.objectClass).to(beIdenticalTo(NSObject.self))
					}
				}
			}

			it("should be able to classify blocks") {
				"block".withCString { cString in
					let propertyPointer = class_getProperty(object.dynamicType, cString)
					expect(propertyPointer) != nil as COpaquePointer

					if propertyPointer != nil {
						let attributes = PropertyAttributes(property: propertyPointer)
						expect(attributes.isWeak) == false
						expect(attributes.isObject) == true
						expect(attributes.isBlock) == true
						expect(attributes.objectClass).to(beNil())
					}
				}
			}

			it("should be able to classify non object properties") {
				"integer".withCString { cString in
					let propertyPointer = class_getProperty(object.dynamicType, cString)
					expect(propertyPointer) != nil as COpaquePointer

					if propertyPointer != nil {
						let attributes = PropertyAttributes(property: propertyPointer)
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
