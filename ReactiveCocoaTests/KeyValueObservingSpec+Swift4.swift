import Foundation
@testable import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble

#if swift(>=3.2)
class KeyValueObservingSwift4Spec: QuickSpec {
	override func spec() {
		describe("NSObject.signal(forKeyPath:)") {
			it("should not send the initial value") {
				let object = ObservableObject()
				var values: [Int] = []

				object.reactive
					.signal(for: \.rac_value)
					.observeValues { values.append($0) }

				expect(values) == []
			}

			itBehavesLike("a reactive key value observer using Swift 4 Smart Key Path") {
				["observe": "signal"]
			}
		}

		describe("NSObject.producer(forKeyPath:)") {
			it("should send the initial value") {
				let object = ObservableObject()
				var values: [Int] = []

				object.reactive
					.producer(for: \.rac_value)
					.startWithValues { value in
						values.append(value)
					}

				expect(values) == [0]
			}

			it("should send the initial value for nested key path") {
				let parentObject = NestedObservableObject()
				var values: [Int] = []

				parentObject
					.reactive
					.producer(for: \.rac_object.rac_value)
					.startWithValues { values.append($0) }

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

			itBehavesLike("a reactive key value observer using Swift 4 Smart Key Path") {
				["observe": "producer"]
			}
		}
	}
}

// Shared examples to ensure both `signal(forKeyPath:)` and `producer(forKeyPath:)`
// share common behavior.
fileprivate class KeyValueObservingSwift4SpecConfiguration: QuickConfiguration {
	class Context {
		let context: [String: Any]

		init(_ context: [String: Any]) {
			self.context = context
		}

		func observe<Object: NSObject, U>(_ object: Object, _ keyPath: KeyPath<Object, U?>) -> SignalProducer<U?, NoError> {
			switch context["observe"] {
			case let context as String where context == "signal":
				return SignalProducer(object.reactive.signal(for: keyPath))

			case let context as String where context == "producer":
				return object.reactive.producer(for: keyPath).skip(first: 1)

			default:
				fatalError("Unknown test config.")
			}
		}

		func observe<Object: NSObject, U>(_ object: Object, _ keyPath: KeyPath<Object, U>) -> SignalProducer<U, NoError> {
			switch context["observe"] {
			case let context as String where context == "signal":
				return SignalProducer(object.reactive.signal(for: keyPath))

			case let context as String where context == "producer":
				return object.reactive.producer(for: keyPath).skip(first: 1)

			default:
				fatalError("Unknown test config.")
			}
		}

		func isFinished(_ object: Operation) -> SignalProducer<Bool, NoError> {
			return observe(object, \.isFinished)
		}

		func changes(_ object: ObservableObject) -> SignalProducer<Int, NoError> {
			return observe(object, \.rac_value)
		}

		func nestedChanges(_ object: NestedObservableObject) -> SignalProducer<Int, NoError> {
			return observe(object, \.rac_object.rac_value)
		}

		func weakNestedChanges(_ object: NestedObservableObject) -> SignalProducer<Int?, NoError> {
			return observe(object, \.rac_weakObject?.rac_value)
		}

		func strongReferenceChanges(_ object: ObservableObject) -> SignalProducer<AnyObject?, NoError> {
			return observe(object, \.target)
		}

		func weakReferenceChanges(_ object: ObservableObject) -> SignalProducer<AnyObject?, NoError> {
			return observe(object, \.weakTarget)
		}

		func dependentKeyChanges(_ object: ObservableObject) -> SignalProducer<NSDecimalNumber, NoError> {
			return observe(object, \.rac_value_plusOne)
		}
	}

	override class func configure(_ configuration: Configuration) {
		sharedExamples("a reactive key value observer using Swift 4 Smart Key Path") { (sharedExampleContext: @escaping SharedExampleContext) in
			var context: Context!

			beforeEach { context = Context(sharedExampleContext()) }
			afterEach { context = nil }

			it("should send new values for the key path (even if the value remains unchanged)") {
				let object = ObservableObject()
				var values: [Int] = []

				context.changes(object).startWithValues {
					values.append($0)
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
					values.append($0)
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

				// NOTE: Compiler segfault with key path literals refering to weak
				//       properties.
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
						values.append($0)
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
					var values: [Int?] = []

					context.weakNestedChanges(parentObject).startWithValues {
						values.append($0)
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
					// NOTE: The producer version of this test cases somehow
					//       fails when the spec is being run alone.
					let parentObject = NestedObservableObject()

					weak var weakOriginalInner: ObservableObject? = parentObject.rac_object
					expect(weakOriginalInner).toNot(beNil())

					autoreleasepool {
						_ = context
							.nestedChanges(parentObject)
							.start()
					}

					autoreleasepool {
						parentObject.rac_object = ObservableObject()
					}

					expect(weakOriginalInner).to(beNil())
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
						.startWithValues { observedValue = $0 }

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
						.startWithValues { observedValue = $0 }

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
						.startWithValues { observedValue = $0 }

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
							.startWithValues { value in
								OSAtomicAdd64(Int64(value), &atomicCounter)
							}
					}

					testObject.rac_value = 2

					expect(atomicCounter).toEventually(equal(Int64(numIterations * 2)), timeout: 30.0)
				}

				// ReactiveCocoa/ReactiveCocoa#1122
				it("async disposal of observer") {
					let serialDisposable = SerialDisposable()

					iterationQueue.async {
						DispatchQueue.concurrentPerform(iterations: numIterations) { index in
							let disposable = context.changes(testObject)
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

					let replayProducer = context.changes(testObject)
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
#endif
