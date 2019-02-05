import Foundation
@testable import ReactiveCocoa
@testable import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble

class KeyValueObservingSpec: QuickSpec {
	override func spec() {
		describe("NSObject.signal(forKeyPath:)") {
			it("should not send the initial value") {
				let object = ObservableObject()
				var values: [Int] = []

				object.reactive
					.signal(forKeyPath: #keyPath(ObservableObject.rac_value))
					.observeValues { values.append(($0 as! NSNumber).intValue) }

				expect(values) == []
			}

			itBehavesLike("a reactive key value observer") {
				[
					"observe": { (object: NSObject, keyPath: String) in
						return object.reactive.signal(forKeyPath: keyPath)
					}
				]
			}
		}

		describe("NSObject.producer(forKeyPath:)") {
			it("should send the initial value") {
				let object = ObservableObject()
				var values: [Int] = []

				object.reactive
					.producer(forKeyPath: #keyPath(ObservableObject.rac_value))
					.startWithValues { value in
						values.append(value as! Int)
					}

				expect(values) == [0]
			}

			it("should send the initial value for nested key path") {
				let parentObject = NestedObservableObject()
				var values: [Int] = []

				parentObject
					.reactive
					.producer(forKeyPath: #keyPath(NestedObservableObject.rac_object.rac_value))
					.startWithValues { values.append(($0 as! NSNumber).intValue) }

				expect(values) == [0]
			}

			it("should send the initial value for weak nested key path") {
				let parentObject = NestedObservableObject()
				let innerObject = Optional(ObservableObject())
				parentObject.rac_weakObject = innerObject
				var values: [Int] = []

				parentObject
					.reactive
					.producer(forKeyPath: "rac_weakObject.rac_value")
					.startWithValues { values.append(($0 as! NSNumber).intValue) }

				expect(values) == [0]
			}

			itBehavesLike("a reactive key value observer") {
				[
					"observe": { (object: NSObject, keyPath: String) in
						return object.reactive.producer(forKeyPath: keyPath)
					}
				]
			}
		}

		describe("property type and attribute query") {
			let object = TestAttributeQueryObject()

			it("should be able to classify weak references") {
				"weakProperty".withCString { cString in
					let propertyPointer = class_getProperty(type(of: object), cString)
					expect(propertyPointer).toNot(beNil())

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
					expect(propertyPointer).toNot(beNil())

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
					expect(propertyPointer).toNot(beNil())

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

// Shared examples to ensure both `signal(forKeyPath:)` and `producer(forKeyPath:)`
// share common behavior.
fileprivate class KeyValueObservingSpecConfiguration: QuickConfiguration {
	class Context {
		let context: [String: Any]

		init(_ context: [String: Any]) {
			self.context = context
		}

		func observe(_ object: NSObject, _ keyPath: String) -> SignalProducer<Any?, NoError> {
			if let block = context["observe"] as? (NSObject, String) -> Signal<Any?, NoError> {
				return SignalProducer(block(object, keyPath))
			} else if let block = context["observe"] as? (NSObject, String) -> SignalProducer<Any?, NoError> {
				return block(object, keyPath).skip(first: 1)
			} else {
				fatalError("What is this?")
			}
		}

		func isFinished(_ object: Operation) -> SignalProducer<Any?, NoError> {
			return observe(object, #keyPath(Operation.isFinished))
		}

		func changes(_ object: NSObject) -> SignalProducer<Any?, NoError> {
			return observe(object, #keyPath(ObservableObject.rac_value))
		}

		func nestedChanges(_ object: NSObject) -> SignalProducer<Any?, NoError> {
			return observe(object, #keyPath(NestedObservableObject.rac_object.rac_value))
		}

		func weakNestedChanges(_ object: NSObject) -> SignalProducer<Any?, NoError> {
			// `#keyPath` does not work with weak relationships.
			return observe(object, "rac_weakObject.rac_value")
		}

		func strongReferenceChanges(_ object: NSObject) -> SignalProducer<Any?, NoError> {
			return observe(object, #keyPath(ObservableObject.target))
		}

		func weakReferenceChanges(_ object: NSObject) -> SignalProducer<Any?, NoError> {
			return observe(object, #keyPath(ObservableObject.weakTarget))
		}

		func dependentKeyChanges(_ object: NSObject) -> SignalProducer<Any?, NoError> {
			return observe(object, #keyPath(ObservableObject.rac_value_plusOne))
		}
	}

	override class func configure(_ configuration: Configuration) {
		sharedExamples("a reactive key value observer") { (sharedExampleContext: @escaping SharedExampleContext) in
			var context: Context!

			beforeEach { context = Context(sharedExampleContext()) }
			afterEach { context = nil }

			it("should send new values for the key path (even if the value remains unchanged)") {
				let object = ObservableObject()
				var values: [Int] = []

				context.changes(object).startWithValues {
					values.append(($0 as! NSNumber).intValue)
				}

				expect(values) == []

				object.rac_value = 0
				expect(values) == [0]

				object.rac_value = 1
				expect(values) == [0, 1]

				object.rac_value = 1
				expect(values) == [0, 1, 1]
			}

			it("should send new values for the dependent key path") {
				// This variant wraps the setter invocations with an autoreleasepool, and
				// intentionally avoids retaining the emitted value, so that a bug that
				// emits `nil` inappropriately can be caught.
				//
				// Related: https://github.com/ReactiveCocoa/ReactiveCocoa/issues/3443#issuecomment-292721863
				// Fixed in https://github.com/ReactiveCocoa/ReactiveCocoa/pull/3439.

				let object = ObservableObject()
				var expectedResults = [1, 2, 2]
				var unexpectedResults: [NSDecimalNumber?] = []

				var matches = true

				context.dependentKeyChanges(object).startWithValues { number in
					let number = number as? NSDecimalNumber

					if number != NSDecimalNumber(value: expectedResults.removeFirst()) {
						matches = false
						unexpectedResults.append(number)
					}
				}

				expect(matches) == true
				expect(unexpectedResults as NSArray) == []

				autoreleasepool {
					object.rac_value = 0
				}

				expect(matches) == true
				expect(unexpectedResults as NSArray) == []


				autoreleasepool {
					object.rac_value = 1
				}

				expect(matches) == true
				expect(unexpectedResults as NSArray) == []

				autoreleasepool {
					object.rac_value = 1
				}

				expect(matches) == true
				expect(unexpectedResults as NSArray) == []
			}

			it("should send new values for the dependent key path (even if the value remains unchanged)") {
				let object = ObservableObject()
				var values: [NSDecimalNumber] = []

				context.dependentKeyChanges(object).startWithValues {
					values.append($0 as! NSDecimalNumber)
				}

				expect(values) == []

				object.rac_value = 0
				expect(values) == [1]

				object.rac_value = 1
				expect(values) == [1, 2]

				object.rac_value = 1
				expect(values) == [1, 2, 2]
			}

			it("should not crash an Operation") {
				// Related issue:
				// https://github.com/ReactiveCocoa/ReactiveCocoa/issues/3329
				func invoke() {
					let op = Operation()
					context.isFinished(op).start()
				}

				invoke()
			}

			describe("signal behavior") {
				it("should complete when the object deallocates") {
					var completed = false

					_ = {
						// Use a closure so this object has a shorter lifetime.
						let object = ObservableObject()

						context.changes(object).startWithCompleted {
							completed = true
						}

						expect(completed) == false
					}()

					expect(completed).toEventually(beTruthy())
				}

				it("should support native Swift objects") {
					let object = ObservableObject()
					var value: Any?

					context
						.strongReferenceChanges(object)
						.startWithValues { value = $0 }

					expect(value).to(beNil())

					let token = Token()
					object.target = token
					expect(value).to(beIdenticalTo(token))
				}

				it("should emit a `nil` when the key path is being cleared due to the deallocation of the Objective-C object it held.") {
					let object = ObservableObject()
					let null = ObjectIdentifier(NSNull())
					var ids: [ObjectIdentifier] = []

					context
						.weakReferenceChanges(object)
						.startWithValues { ids.append($0.map { ObjectIdentifier($0 as AnyObject) } ?? null) }

					expect(ids) == []

					var token: NSObject? = NSObject()
					let tokenId = ObjectIdentifier(token!)

					// KVO would create autoreleasing references of the values being
					// passed. So we have to ensure that they are cleared before
					// we move on.
					autoreleasepool {
						object.weakTarget = token
					}

					expect(ids) == [tokenId]

					token = nil

					expect(ids) == [tokenId, null]
					expect(object.weakTarget).to(beNil())
				}

				it("should emit a `nil` when the key path is being cleared due to the deallocation of the native Swift object it held.") {
					let object = ObservableObject()
					let null = ObjectIdentifier(NSNull())
					var ids: [ObjectIdentifier] = []

					context
						.weakReferenceChanges(object)
						.startWithValues { ids.append($0.map { ObjectIdentifier($0 as AnyObject) } ?? null) }

					expect(ids) == []

					var token: Token? = Token()
					let tokenId = ObjectIdentifier(token!)

					// KVO would create autoreleasing references of the values being
					// passed. So we have to ensure that they are cleared before
					// we move on.
					autoreleasepool {
						object.weakTarget = token
					}

					expect(ids) == [tokenId]

					token = nil
					
					expect(ids) == [tokenId, null]
					expect(object.weakTarget).to(beNil())
				}
			}

			describe("nested key paths") {
				it("should observe changes in a nested key path") {
					let parentObject = NestedObservableObject()
					var values: [Int] = []

					context.nestedChanges(parentObject).startWithValues {
						values.append(($0 as! NSNumber).intValue)
					}

					expect(values) == []

					parentObject.rac_object.rac_value = 1
					expect(values) == [1]

					let oldInnerObject = parentObject.rac_object

					let newInnerObject = ObservableObject()
					parentObject.rac_object = newInnerObject
					expect(values) == [1, 0]

					parentObject.rac_object.rac_value = 10
					oldInnerObject.rac_value = 2
					expect(values) == [1, 0, 10]
				}

				it("should observe changes in a nested weak key path") {
					let parentObject = NestedObservableObject()
					var innerObject = Optional(ObservableObject())
					parentObject.rac_weakObject = innerObject
					var values: [Int] = []

					context.weakNestedChanges(parentObject).startWithValues {
						values.append(($0 as! NSNumber).intValue)
					}

					expect(values) == []

					innerObject?.rac_value = 1
					expect(values) == [1]

					autoreleasepool {
						innerObject = nil
					}

					// NOTE: [1] or [Optional(1), nil]?
					expect(values) == [1]

					innerObject = ObservableObject()
					parentObject.rac_weakObject = innerObject
					expect(values) == [1, 0]
					
					innerObject?.rac_value = 10
					expect(values) == [1, 0, 10]
				}

				it("should not retain replaced value in a nested key path") {
					weak var weakOriginalInner: ObservableObject?
					let parentObject = NestedObservableObject()

					autoreleasepool {
						parentObject.rac_object = ObservableObject()
						weakOriginalInner = parentObject.rac_object

						expect(weakOriginalInner).toNot(beNil())

						_ = context
							.nestedChanges(parentObject)
							.start()

						parentObject.rac_object = ObservableObject()
					}

					expect(weakOriginalInner).to(beNil())
				}

				it("should not observe changes on a replaced inner object in a nested key path") {
					let parentObject = NestedObservableObject()

					// This test case requires a nil value which `rac_object` doesn't
					// allow, so we are going to use `rac_weakObject` instead.
					// The tested inner objects are not meant to be weak in any way.
					let oldInnerObject = ObservableObject()
					parentObject.rac_weakObject = oldInnerObject

					var values: [Int?] = []

					context.weakNestedChanges(parentObject).startWithValues {
						values.append($0 as! Int?)
					}

					expect(values) == []

					oldInnerObject.rac_value = 1
					expect(values) == [1]

					parentObject.rac_weakObject = nil
					expect(values) == [1, nil]

					oldInnerObject.rac_value = 2
					expect(values) == [1, nil]

					let newInnerObject = ObservableObject()
					parentObject.rac_weakObject = newInnerObject

					expect(values) == [1, nil, 0]

					oldInnerObject.rac_value = 3
					expect(values) == [1, nil, 0]

					newInnerObject.rac_value = 4
					expect(values) == [1, nil, 0, 4]
				}
			}

			describe("thread safety") {
				var concurrentQueue: DispatchQueue!

				beforeEach {
					concurrentQueue = DispatchQueue(
						label: "org.reactivecocoa.ReactiveCocoa.DynamicPropertySpec.concurrentQueue",
						attributes: .concurrent
					)
				}

				it("should handle changes being made on another queue") {
					let object = ObservableObject()
					var observedValue = 0

					context.changes(object)
						.take(first: 1)
						.startWithValues { observedValue = ($0 as! NSNumber).intValue }

					concurrentQueue.async {
						object.rac_value = 2
					}

					concurrentQueue.sync(flags: .barrier) {}
					expect(observedValue).toEventually(equal(2))
				}

				it("should handle changes being made on another queue using deliverOn") {
					let object = ObservableObject()
					var observedValue = 0

					context.changes(object)
						.take(first: 1)
						.observe(on: UIScheduler())
						.startWithValues { observedValue = ($0 as! NSNumber).intValue }

					concurrentQueue.async {
						object.rac_value = 2
					}

					concurrentQueue.sync(flags: .barrier) {}
					expect(observedValue).toEventually(equal(2))
				}

				it("async disposal of target") {
					var object: ObservableObject? = ObservableObject()
					var observedValue = 0

					context.changes(object!)
						.observe(on: UIScheduler())
						.startWithValues { observedValue = ($0 as! NSNumber).intValue }

					concurrentQueue.async {
						object!.rac_value = 2
						object = nil
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
					iterationQueue = DispatchQueue(
						label: "org.reactivecocoa.ReactiveCocoa.RACKVOProxySpec.iterationQueue",
						attributes: .concurrent
					)
					concurrentQueue = DispatchQueue(
						label: "org.reactivecocoa.ReactiveCocoa.DynamicPropertySpec.concurrentQueue",
						attributes: .concurrent
					)
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
						context.changes(testObject)
							.observe(on: deliveringObserver)
							.map { $0 as! NSNumber }
							.map { $0.int64Value }
							.startWithValues { value in
								OSAtomicAdd64(value, &atomicCounter)
							}
					}

					testObject.rac_value = 2

					expect(atomicCounter).toEventually(equal(Int64(numIterations * 2)), timeout: 30.0)
				}

				// Direct port of https://github.com/ReactiveCocoa/ReactiveObjC/blob/3.1.0/ReactiveObjCTests/RACKVOProxySpec.m#L196
				it("async disposal of observer") {
					let serialDisposable = SerialDisposable()
					let lock = Lock.make()

					iterationQueue.async {
						DispatchQueue.concurrentPerform(iterations: numIterations) { index in
							let disposable = context.changes(testObject)
								.startWithCompleted {}

							serialDisposable.inner = disposable

							concurrentQueue.async {
								// TestObject in the ObjC version has manual getter, setter and KVO notification. Here
								// we just wrap the call with a `Lock` to emulate the effect.
								lock.lock()
								testObject.rac_value = index
								lock.unlock()
							}
						}
					}

					iterationQueue.sync(flags: .barrier) {
						serialDisposable.dispose()
					}
				}

				// Direct port of https://github.com/ReactiveCocoa/ReactiveObjC/blob/3.1.0/ReactiveObjCTests/RACKVOProxySpec.m#L196
				it("async disposal of signal with in-flight changes") {
					let otherScheduler: QueueScheduler

					var token = Optional(Lifetime.Token())
					let lifetime = Lifetime(token!)

					if #available(*, OSX 10.10) {
						otherScheduler = QueueScheduler(name: "\(#file):\(#line)")
					} else {
						otherScheduler = QueueScheduler(queue: DispatchQueue(label: "\(#file):\(#line)"))
					}

					let replayProducer = context.changes(testObject)
						.map { ($0 as! NSNumber).intValue }
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
	}
}

private final class Token {}

private class ObservableObject: NSObject {
	@objc dynamic var rac_value: Int = 0

	@objc dynamic var target: AnyObject?
	@objc dynamic weak var weakTarget: AnyObject?

	@objc dynamic var rac_value_plusOne: NSDecimalNumber {
		return NSDecimalNumber(value: rac_value + 1)
	}

	override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
		if key == "rac_value_plusOne" {
			return Set([#keyPath(ObservableObject.rac_value)])
		} else {
			return Set()
		}
	}
}

private class NestedObservableObject: NSObject {
	@objc dynamic var rac_object: ObservableObject = ObservableObject()
	@objc dynamic weak var rac_weakObject: ObservableObject?
}

private class TestAttributeQueryObject: NSObject {
	@objc weak var weakProperty: NSObject? = nil
	@objc var block: @convention(block) (NSObject) -> NSObject? = { _ in nil }
	@objc let integer = 0
}
