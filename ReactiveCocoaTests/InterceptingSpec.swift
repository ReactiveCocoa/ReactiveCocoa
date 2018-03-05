import Foundation
@testable import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble
import CoreGraphics

class InterceptingSpec: QuickSpec {
	override func spec() {
		beforeSuite {
			ForwardInvocationTestObject._initialize()
		}

		describe("trigger(for:)") {
			var object: InterceptedObject!
			weak var _object: InterceptedObject?

			beforeEach {
				object = InterceptedObject()
				_object = object
			}

			afterEach {
				object = nil
				expect(_object).to(beNil())
			}

			it("should send a value when the selector is invoked") {
				let signal = object.reactive.trigger(for: #selector(object.increment))

				var counter = 0
				signal.observeValues { counter += 1 }

				expect(counter) == 0
				expect(object.counter) == 0

				object.increment()
				expect(counter) == 1
				expect(object.counter) == 1

				object.increment()
				expect(counter) == 2
				expect(object.counter) == 2
			}

			it("should complete when the object deinitializes") {
				let signal = object.reactive.trigger(for: #selector(object.increment))

				var isCompleted = false
				signal.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object = nil
				expect(_object).to(beNil())
				expect(isCompleted) == true
			}

			it("should multicast") {
				let signal1 = object.reactive.trigger(for: #selector(object.increment))
				let signal2 = object.reactive.trigger(for: #selector(object.increment))

				var counter1 = 0
				var counter2 = 0
				signal1.observeValues { counter1 += 1 }
				signal2.observeValues { counter2 += 1 }

				expect(counter1) == 0
				expect(counter2) == 0

				object.increment()
				expect(counter1) == 1
				expect(counter2) == 1

				object.increment()
				expect(counter1) == 2
				expect(counter2) == 2
			}

			it("should not deadlock") {
				for _ in 1 ... 10 {
					var isDeadlocked = true

					func createQueue() -> DispatchQueue {
						if #available(*, macOS 10.10) {
							return .global(qos: .userInitiated)
						} else {
							return .global(priority: .high)
						}
					}

					createQueue().async {
						_ = object.reactive.trigger(for: #selector(object.increment))

						createQueue().async {
							_ = object.reactive.trigger(for: #selector(object.increment))

							isDeadlocked = false
						}
					}

					expect(isDeadlocked).toEventually(beFalsy())
				}
			}

			it("should send completed on deallocation") {
				var completed = false
				var deallocated = false

				autoreleasepool {
					let object = InterceptedObject()

					object.reactive.lifetime.ended.observeCompleted {
						deallocated = true
					}

					object.reactive.trigger(for: #selector(object.lifeIsGood)).observeCompleted {
						completed = true
					}

					expect(deallocated) == false
					expect(completed) == false
				}

				expect(deallocated) == true
				expect(completed) == true
			}

			it("should send arguments for invocation and invoke the original method on previously KVO'd receiver") {
				var latestValue: Bool?

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.startWithValues { objectValue in
						latestValue = objectValue as! Bool?
				}

				expect(latestValue).to(beNil())

				var firstValue: Bool?
				var secondValue: String?

				object.reactive
					.signal(for: #selector(object.set(first:second:)))
					.observeValues { x in
						firstValue = x[0] as! Bool?
						secondValue = x[1] as! String?
				}

				object.set(first: true, second: "Winner")

				expect(object.hasInvokedSetObjectValueAndSecondObjectValue) == true
				expect(object.objectValue as! Bool?) == true
				expect(object.secondObjectValue as! String?) == "Winner"

				expect(latestValue) == true

				expect(firstValue) == true
				expect(secondValue) == "Winner"
			}

			it("should send arguments for invocation and invoke the a KVO-swizzled then RAC-swizzled setter") {
				var latestValue: Bool?

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.startWithValues { objectValue in
						latestValue = objectValue as! Bool?
				}

				expect(latestValue).to(beNil())

				var value: Bool?
				object.reactive.signal(for: #selector(setter: object.objectValue)).observeValues { x in
					value = x[0] as! Bool?
				}

				object.objectValue = true

				expect(object.objectValue as! Bool?) == true
				expect(latestValue) == true
				expect(value) == true
			}

			it("should send arguments for invocation and invoke the a RAC-swizzled then KVO-swizzled setter") {
				let object = InterceptedObject()

				var value: Bool?
				object.reactive.signal(for: #selector(setter: object.objectValue)).observeValues { x in
					value = x[0] as! Bool?
				}

				var latestValue: Bool?

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.startWithValues { objectValue in
						latestValue = objectValue as! Bool?
				}

				expect(latestValue).to(beNil())

				object.objectValue = true

				expect(object.objectValue as! Bool?) == true
				expect(latestValue) == true
				expect(value) == true
			}

			it("should send arguments for invocation and invoke the original method when receiver is subsequently KVO'd") {
				let object = InterceptedObject()

				var firstValue: Bool?
				var secondValue: String?

				object.reactive.signal(for: #selector(object.set(first:second:))).observeValues { x in
					firstValue = x[0] as! Bool?
					secondValue = x[1] as! String?
				}

				var latestValue: Bool?

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.startWithValues { objectValue in
						latestValue = objectValue as! Bool?
				}

				expect(latestValue).to(beNil())

				object.set(first: true, second: "Winner")

				expect(object.hasInvokedSetObjectValueAndSecondObjectValue) == true
				expect(object.objectValue as! Bool?) == true
				expect(object.secondObjectValue as! String?) == "Winner"

				expect(latestValue) == true

				expect(firstValue) == true
				expect(secondValue) == "Winner"
			}

			it("should send a value event for every invocation of a method on a receiver that is subsequently KVO'd twice") {
				var counter = 0

				object.reactive.trigger(for: #selector(setter: InterceptedObject.objectValue))
					.observeValues { counter += 1 }

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()
					.dispose()

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				expect(counter) == 0

				object.objectValue = 1
				expect(counter) == 1

				object.objectValue = 1
				expect(counter) == 2
			}

			it("should send a value event for every invocation of a method on a receiver that is KVO'd twice while being swizzled by RAC in between") {
				var counter = 0

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()
					.dispose()

				object.reactive.trigger(for: #selector(setter: InterceptedObject.objectValue))
					.observeValues { counter += 1 }

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				expect(counter) == 0

				object.objectValue = 1
				expect(counter) == 1

				object.objectValue = 1
				expect(counter) == 2
			}

			it("should call the right signal for two instances of the same class, adding signals for the same selector") {
				let object1 = InterceptedObject()
				let object2 = InterceptedObject()

				let selector = NSSelectorFromString("lifeIsGood:")

				var value1: Int?
				object1.reactive.signal(for: selector).observeValues { x in
					value1 = x[0] as! Int?
				}

				var value2: Int?
				object2.reactive.signal(for: selector).observeValues { x in
					value2 = x[0] as! Int?
				}

				object1.lifeIsGood(42)
				expect(value1) == 42
				expect(value2).to(beNil())

				object2.lifeIsGood(420)
				expect(value1) == 42
				expect(value2) == 420
			}

			it("should send on signal after the original method is invoked") {
				let object = InterceptedObject()

				var invokedMethodBefore = false
				object.reactive.trigger(for: #selector(object.set(first:second:))).observeValues {
					invokedMethodBefore = object.hasInvokedSetObjectValueAndSecondObjectValue
				}

				object.set(first: true, second: "Winner")
				expect(invokedMethodBefore) == true
			}
		}

		describe("interoperability") {
			var invoked: Bool!
			var object: InterceptedObject!
			var originalClass: AnyClass!

			beforeEach {
				invoked = false
				object = InterceptedObject()
				originalClass = InterceptedObject.self
			}

			it("should invoke the swizzled `forwardInvocation:` on an instance isa-swizzled by both RAC and KVO.") {
				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))

				let swizzledSelector = #selector(object.lifeIsGood)

				// Redirect `swizzledSelector` to the forwarding machinery.
				let method = class_getInstanceMethod(originalClass, swizzledSelector)!
				let typeEncoding = method_getTypeEncoding(method)

				let original = class_replaceMethod(originalClass,
				                                   swizzledSelector,
				                                   _rac_objc_msgForward,
				                                   typeEncoding) ?? noImplementation
				defer {
					_ = class_replaceMethod(originalClass,
					                        swizzledSelector,
					                        original,
					                        typeEncoding)
				}

				// Swizzle `forwardInvocation:` to intercept `swizzledSelector`.
				let forwardInvocationBlock: @convention(block) (AnyObject, AnyObject) -> Void = { _, invocation in
					if (invocation.selector == swizzledSelector) {
						expect(invoked) == false
						invoked = true
					}
				}

				let method2 = class_getInstanceMethod(originalClass, ObjCSelector.forwardInvocation)!
				let typeEncoding2 = method_getTypeEncoding(method2)

				let original2 = class_replaceMethod(originalClass,
				                                    ObjCSelector.forwardInvocation,
				                                    imp_implementationWithBlock(forwardInvocationBlock as Any),
				                                    typeEncoding2) ?? noImplementation
				defer {
					_ = class_replaceMethod(originalClass,
					                        ObjCSelector.forwardInvocation,
					                        original2,
					                        typeEncoding2)
				}

				object.lifeIsGood(nil)
				expect(invoked) == true
			}

			it("should invoke the swizzled `forwardInvocation:` on an instance isa-swizzled by RAC.") {
				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))

				let swizzledSelector = #selector(object.lifeIsGood)

				// Redirect `swizzledSelector` to the forwarding machinery.
				let method = class_getInstanceMethod(originalClass, swizzledSelector)!
				let typeEncoding = method_getTypeEncoding(method)

				let original = class_replaceMethod(originalClass,
				                                   swizzledSelector,
				                                   _rac_objc_msgForward,
				                                   typeEncoding) ?? noImplementation
				defer {
					_ = class_replaceMethod(originalClass,
					                        swizzledSelector,
					                        original,
					                        typeEncoding)
				}

				// Swizzle `forwardInvocation:` to intercept `swizzledSelector`.
				let forwardInvocationBlock: @convention(block) (AnyObject, AnyObject) -> Void = { _, invocation in
					if (invocation.selector == swizzledSelector) {
						expect(invoked) == false
						invoked = true
					}
				}

				let method2 = class_getInstanceMethod(originalClass, ObjCSelector.forwardInvocation)!
				let typeEncoding2 = method_getTypeEncoding(method2)

				let original2 = class_replaceMethod(originalClass,
				                                    ObjCSelector.forwardInvocation,
				                                    imp_implementationWithBlock(forwardInvocationBlock as Any),
				                                    typeEncoding2) ?? noImplementation
				defer {
					_ = class_replaceMethod(originalClass,
					                        ObjCSelector.forwardInvocation,
					                        original2,
					                        typeEncoding2)
				}

				object.lifeIsGood(nil)
				expect(invoked) == true
			}

			it("should invoke the swizzled selector on an instance isa-swizzled by RAC.") {
				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))

				let swizzledSelector = #selector(object.lifeIsGood)

				let lifeIsGoodBlock: @convention(block) (AnyObject, AnyObject) -> Void = { _, _ in
					expect(invoked) == false
					invoked = true
				}

				let method = class_getInstanceMethod(originalClass, swizzledSelector)!
				let typeEncoding = method_getTypeEncoding(method)

				let original = class_replaceMethod(originalClass,
				                                   swizzledSelector,
				                                   imp_implementationWithBlock(lifeIsGoodBlock as Any),
				                                   typeEncoding) ?? noImplementation
				defer {
					_ = class_replaceMethod(originalClass,
					                        swizzledSelector,
					                        original,
					                        typeEncoding)
				}

				object.lifeIsGood(nil)
				expect(invoked) == true
			}
		}

		it("should swizzle an NSObject method") {
			let object = NSObject()

			var value: [Any?]?

			object.reactive
				.signal(for: #selector(getter: object.description))
				.observeValues { x in
					value = x
			}

			expect(value).to(beNil())

			expect(object.description).notTo(beNil())
			expect(value).toNot(beNil())
		}

		describe("a class that already overrides -forwardInvocation:") {
			it("should invoke the superclass' implementation") {
				let object = ForwardInvocationTestObject()

				var value: Int?
				object.reactive
					.signal(for: #selector(object.lifeIsGood))
					.observeValues { x in
						value = x[0] as! Int?
				}

				object.lifeIsGood(42)
				expect(value) == 42

				expect(object.forwardedCount) == 0

				object.perform(ForwardInvocationTestObject.forwardedSelector)

				expect(object.forwardedCount) == 1
				expect(object.forwardedSelector) == ForwardInvocationTestObject.forwardedSelector
			}

			it("should not infinite recurse when KVO'd after RAC swizzled") {
				let object = ForwardInvocationTestObject()

				var value: Int?

				object.reactive
					.signal(for: #selector(object.lifeIsGood))
					.observeValues { x in
						value = x[0] as! Int?
				}

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				object.lifeIsGood(42)
				expect(value) == 42

				expect(object.forwardedCount) == 0

				object.perform(ForwardInvocationTestObject.forwardedSelector)

				expect(object.forwardedCount) == 1
				expect(object.forwardedSelector) == ForwardInvocationTestObject.forwardedSelector
			}
		}

		describe("two classes in the same hierarchy") {
			var superclassObj: InterceptedObject!
			var superclassTuple: [Any]!

			var subclassObj: InterceptedObjectSubclass!
			var subclassTuple: [Any]!

			beforeEach {
				superclassObj = InterceptedObject()
				expect(superclassObj).notTo(beNil())

				subclassObj = InterceptedObjectSubclass()
				expect(subclassObj).notTo(beNil())
			}

			it("should not collide") {
				superclassObj.reactive
					.signal(for: #selector(InterceptedObject.foo))
					.observeValues { args in
						superclassTuple = args.map { $0 ?? NSNull() }
					}

				subclassObj
					.reactive
					.signal(for: #selector(InterceptedObject.foo))
					.observeValues { args in
						subclassTuple = args.map { $0 ?? NSNull() }
					}

				expect(superclassObj.foo(40, "foo")) == "Not Subclass 40 foo"

				let expectedValues = [40, "foo"] as NSArray
				expect(superclassTuple as NSArray) == expectedValues

				expect(subclassObj.foo(40, "foo")) == "Subclass 40 foo"

				expect(subclassTuple as NSArray) == expectedValues
			}

			it("should not collide when the superclass is invoked asynchronously") {
				superclassObj.reactive
					.signal(for: #selector(InterceptedObject.set(first:second:)))
					.observeValues { args in
						superclassTuple = args.map { $0 ?? NSNull() }
				}

				subclassObj
					.reactive
					.signal(for: #selector(InterceptedObject.set(first:second:)))
					.observeValues { args in
						subclassTuple = args.map { $0 ?? NSNull() }
				}

				superclassObj.set(first: "foo", second:"42")
				expect(superclassObj.hasInvokedSetObjectValueAndSecondObjectValue) == true

				let expectedValues = ["foo", "42"] as NSArray
				expect(superclassTuple as NSArray) == expectedValues

				subclassObj.set(first: "foo", second:"42")
				expect(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue) == false
				expect(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue).toEventually(beTruthy())

				expect(subclassTuple as NSArray) == expectedValues
			}
		}

		describe("class reporting") {
			var object: InterceptedObject!
			var originalClass: AnyClass!

			beforeEach {
				object = InterceptedObject()
				originalClass = InterceptedObject.self
			}

			it("should report the original class") {
				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))
				expect((object as AnyObject).objcClass).to(beIdenticalTo(originalClass))
			}

			it("should report the original class when it's KVO'd after dynamically subclassing") {
				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))

				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				expect((object as AnyObject).objcClass).to(beIdenticalTo(originalClass))
			}

			it("should report the original class when it's KVO'd before dynamically subclassing") {
				object.reactive
					.producer(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))
				expect((object as AnyObject).objcClass).to(beIdenticalTo(originalClass))
			}
		}

		describe("signal(for:)") {
			var object: InterceptedObject!
			weak var _object: InterceptedObject?

			beforeEach {
				object = InterceptedObject()
				_object = object
			}

			afterEach {
				object = nil
				expect(_object).to(beNil())
			}

			it("should send a return values") {

				ReturnValueTest<CChar>(object: object).test()
				ReturnValueTest<CShort>(object: object).test()
				ReturnValueTest<CInt>(object: object).test()

				ReturnValueTest<CLong>(object: object).test()
				ReturnValueTest<CLongLong>(object: object).test()
				ReturnValueTest<CUnsignedChar>(object: object).test()
				ReturnValueTest<CUnsignedShort>(object: object).test()
				ReturnValueTest<CUnsignedInt>(object: object).test()
				ReturnValueTest<CUnsignedLong>(object: object).test()
				ReturnValueTest<CUnsignedLongLong>(object: object).test()
				ReturnValueTest<CFloat>(object: object).test()
				ReturnValueTest<CDouble>(object: object).test()
				ReturnValueTest<CBool>(object: object).test()

				ReturnValueTest<NSObject>(object: object).test()

			}

			it("should send a return value nil") {
				
				let signal = object.reactive.signal(for: #selector(object.testReturnValuesObjectOptional(arg:)),
													includeReturnValue:true)

				var arguments = [[Any?]]()
				signal.observeValues { arguments.append($0) }

				expect(arguments.count) == 0

				expect(object.testReturnValuesObjectOptional(arg: nil)).to(beNil())
				expect(arguments.count) == 1

				expect((arguments[0][0] as? NSObject)).to(beNil())
				expect((arguments[0][1] as? NSObject)).to(beNil())

			}

			it("should send a return value AnyClass") {

				let signal = object.reactive.signal(for: #selector(object.testReturnValuesClass(arg:)),
													includeReturnValue:true)

				var arguments = [[Any?]]()
				signal.observeValues { arguments.append($0) }

				expect(arguments.count) == 0

				let c: AnyClass = InterceptedObject.self

				expect(object.testReturnValuesClass(arg: c) is InterceptedObject.Type) == true
				expect(arguments.count) == 1

				expect((arguments[0][0] is InterceptedObject.Type)) == true
				expect((arguments[0][1] is InterceptedObject.Type)) == true

			}


			it("should send a value with bridged numeric arguments") {
				let signal = object.reactive.signal(for: #selector(object.testNumericValues(c:s:i:l:ll:uc:us:ui:ul:ull:f:d:b:)))

				var arguments = [[Any?]]()
				signal.observeValues { arguments.append($0) }

				expect(arguments.count) == 0

				func call(offset: UInt) {
					object.testNumericValues(c: CChar.max - CChar(offset),
					                         s: CShort.max - CShort(offset),
					                         i: CInt.max - CInt(offset),
					                         l: CLong.max - CLong(offset),
					                         ll: CLongLong.max - CLongLong(offset),
					                         uc: CUnsignedChar.max - CUnsignedChar(offset),
					                         us: CUnsignedShort.max - CUnsignedShort(offset),
					                         ui: CUnsignedInt.max - CUnsignedInt(offset),
					                         ul: CUnsignedLong.max - CUnsignedLong(offset),
					                         ull: CUnsignedLongLong.max - CUnsignedLongLong(offset),
					                         f: CFloat.greatestFiniteMagnitude - CFloat(offset),
					                         d: CDouble.greatestFiniteMagnitude - CDouble(offset),
					                         b: offset % 2 == 0 ? true : false)
				}

				func validate(arguments: [Any?], offset: UInt) {
					#if swift(>=3.1)
					expect((arguments[0] as! CChar)) == CChar.max - CChar(offset)
					expect((arguments[1] as! CShort)) == CShort.max - CShort(offset)
					expect((arguments[2] as! CInt)) == CInt.max - CInt(offset)
					expect((arguments[3] as! CLong)) == CLong.max - CLong(offset)
					expect((arguments[4] as! CLongLong)) == CLongLong.max - CLongLong(offset)
					expect((arguments[5] as! CUnsignedChar)) == CUnsignedChar.max - CUnsignedChar(offset)
					expect((arguments[6] as! CUnsignedShort)) == CUnsignedShort.max - CUnsignedShort(offset)
					expect((arguments[7] as! CUnsignedInt)) == CUnsignedInt.max - CUnsignedInt(offset)
					expect((arguments[8] as! CUnsignedLong)) == CUnsignedLong.max - CUnsignedLong(offset)
					expect((arguments[9] as! CUnsignedLongLong)) == CUnsignedLongLong.max - CUnsignedLongLong(offset)
					expect((arguments[10] as! CFloat)) == CFloat.greatestFiniteMagnitude - CFloat(offset)
					expect((arguments[11] as! CDouble)) == CDouble.greatestFiniteMagnitude - CDouble(offset)
					expect((arguments[12] as! Bool)) == (offset % 2 == 0 ? true : false)
					#else
					expect((arguments[0] as! NSNumber).int8Value) == CChar.max - CChar(offset)
					expect((arguments[1] as! NSNumber).int16Value) == CShort.max - CShort(offset)
					expect((arguments[2] as! NSNumber).int32Value) == CInt.max - CInt(offset)
					expect((arguments[3] as! NSNumber).intValue) == CLong.max - CLong(offset)
					expect((arguments[4] as! NSNumber).int64Value) == CLongLong.max - CLongLong(offset)
					expect((arguments[5] as! NSNumber).uint8Value) == CUnsignedChar.max - CUnsignedChar(offset)
					expect((arguments[6] as! NSNumber).uint16Value) == CUnsignedShort.max - CUnsignedShort(offset)
					expect((arguments[7] as! NSNumber).uint32Value) == CUnsignedInt.max - CUnsignedInt(offset)
					expect((arguments[8] as! NSNumber).uintValue) == CUnsignedLong.max - CUnsignedLong(offset)
					expect((arguments[9] as! NSNumber).uint64Value) == CUnsignedLongLong.max - CUnsignedLongLong(offset)
					expect((arguments[10] as! NSNumber).floatValue) == CFloat.greatestFiniteMagnitude - CFloat(offset)
					expect((arguments[11] as! NSNumber).doubleValue) == CDouble.greatestFiniteMagnitude - CDouble(offset)
					expect((arguments[12] as! NSNumber).boolValue) == (offset % 2 == 0 ? true : false)
					#endif
				}

				call(offset: 0)
				expect(arguments.count) == 1
				validate(arguments: arguments[0], offset: 0)

				call(offset: 1)
				expect(arguments.count) == 2
				validate(arguments: arguments[1], offset: 1)

				call(offset: 2)
				expect(arguments.count) == 3
				validate(arguments: arguments[2], offset: 2)
			}

			it("should send a value with bridged reference arguments") {
				let signal = object.reactive.signal(for: #selector(object.testReferences(nonnull:nullable:iuo:class:nullableClass:iuoClass:)))

				var arguments = [[Any?]]()
				signal.observeValues { arguments.append($0) }

				expect(arguments.count) == 0

				let token = NSObject()

				object.testReferences(nonnull: token,
				                      nullable: token,
				                      iuo: token,
				                      class: InterceptingSpec.self,
				                      nullableClass: InterceptingSpec.self,
				                      iuoClass: InterceptingSpec.self)

				expect(arguments.count) == 1

				expect((arguments[0][0] as! NSObject)) == token
				expect(arguments[0][1] as! NSObject?) == token
				expect(arguments[0][2] as! NSObject?) == token
				expect(arguments[0][3] as! AnyClass is InterceptingSpec.Type) == true
				expect(arguments[0][4] as! AnyClass? is InterceptingSpec.Type) == true
				expect(arguments[0][5] as! AnyClass? is InterceptingSpec.Type) == true

				object.testReferences(nonnull: token,
				                      nullable: nil,
				                      iuo: nil,
				                      class: InterceptingSpec.self,
				                      nullableClass: nil,
				                      iuoClass: nil)

				expect(arguments.count) == 2

				expect((arguments[1][0] as! NSObject)) == token
				expect(arguments[1][1] as! NSObject?).to(beNil())
				expect(arguments[1][2] as! NSObject?).to(beNil())
				expect(arguments[1][3] as! AnyClass is InterceptingSpec.Type) == true
				expect(arguments[1][4] as! AnyClass?).to(beNil())
				expect(arguments[1][5] as! AnyClass?).to(beNil())
			}

			it("should send a value with bridged struct arguments") {
				let signal = object.reactive.signal(for: #selector(object.testBridgedStructs(p:s:r:a:)))

				var arguments = [[Any?]]()
				signal.observeValues { arguments.append($0) }

				expect(arguments.count) == 0

				func call(offset: CGFloat) {
					object.testBridgedStructs(p: CGPoint(x: offset, y: offset),
					                          s: CGSize(width: offset, height: offset),
					                          r: CGRect(x: offset, y: offset, width: offset, height: offset),
					                          a: CGAffineTransform(translationX: offset, y: offset))
				}

				func validate(arguments: [Any?], offset: CGFloat) {
					#if swift(>=3.1)
					expect((arguments[0] as! CGPoint)) == CGPoint(x: offset, y: offset)
					expect((arguments[1] as! CGSize)) == CGSize(width: offset, height: offset)
					expect((arguments[2] as! CGRect)) == CGRect(x: offset, y: offset, width: offset, height: offset)
					expect((arguments[3] as! CGAffineTransform)) == CGAffineTransform(translationX: offset, y: offset)
					#elseif os(macOS)
					expect((arguments[0] as! NSValue).pointValue) == CGPoint(x: offset, y: offset)
					expect((arguments[1] as! NSValue).sizeValue) == CGSize(width: offset, height: offset)
					expect((arguments[2] as! NSValue).rectValue) == CGRect(x: offset, y: offset, width: offset, height: offset)
					#else
					expect((arguments[0] as! NSValue).cgPointValue) == CGPoint(x: offset, y: offset)
					expect((arguments[1] as! NSValue).cgSizeValue) == CGSize(width: offset, height: offset)
					expect((arguments[2] as! NSValue).cgRectValue) == CGRect(x: offset, y: offset, width: offset, height: offset)
					expect((arguments[3] as! NSValue).cgAffineTransformValue) == CGAffineTransform(translationX: offset, y: offset)
					#endif
				}

				call(offset: 0)
				expect(arguments.count) == 1
				validate(arguments: arguments[0], offset: 0)

				call(offset: 1)
				expect(arguments.count) == 2
				validate(arguments: arguments[1], offset: 1)

				call(offset: 2)
				expect(arguments.count) == 3
				validate(arguments: arguments[2], offset: 2)
			}

			it("should complete when the object deinitializes") {
				let signal = object.reactive.signal(for: #selector(object.increment))

				var isCompleted = false
				signal.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object = nil
				expect(_object).to(beNil())
				expect(isCompleted) == true
			}

			it("should multicast") {
				let signal1 = object.reactive.signal(for: #selector(object.increment))
				let signal2 = object.reactive.signal(for: #selector(object.increment))

				var counter1 = 0
				var counter2 = 0
				signal1.observeValues { _ in counter1 += 1 }
				signal2.observeValues { _ in counter2 += 1 }

				expect(counter1) == 0
				expect(counter2) == 0

				object.increment()
				expect(counter1) == 1
				expect(counter2) == 1

				object.increment()
				expect(counter1) == 2
				expect(counter2) == 2
			}

			it("should not deadlock") {
				for _ in 1 ... 10 {
					var isDeadlocked = true

					DispatchQueue.global(priority: .high).async {
						_ = object.reactive.signal(for: #selector(object.increment))

						DispatchQueue.global(priority: .high).async {
							_ = object.reactive.signal(for: #selector(object.increment))

							isDeadlocked = false
						}
					}

					expect(isDeadlocked).toEventually(beFalsy())
				}
			}
		}

		describe("classes utilising the message forwarding mechanism") {
			it("should receive the message without needing to implement it in the runtime") {
				let entity = MessageForwardingEntity()
				expect(entity.hasInvoked) == false

				var latestValue: Bool?
				entity.reactive
					.signal(for: #selector(setter: entity.hasInvoked))
					.observeValues { latestValue = $0[0] as? Bool }

				expect(entity.hasInvoked) == false
				expect(latestValue).to(beNil())

				entity.perform(Selector(("_rac_test_forwarding")))
				expect(entity.hasInvoked) == true
				expect(latestValue) == true
			}
		}
	}
}

private class ForwardInvocationTestObject: InterceptedObject {
	static let forwardedSelector = Selector((("forwarded")))

	var forwardedCount = 0
	var forwardedSelector: Selector?

	fileprivate static func _initialize() {
		let impl: @convention(c) (Any, Selector, AnyObject) -> Void = { object, _, invocation in
			let object = object as! ForwardInvocationTestObject
			object.forwardedCount += 1
			object.forwardedSelector = invocation.selector
		}

		let success = class_addMethod(ForwardInvocationTestObject.self,
		                              ObjCSelector.forwardInvocation,
		                              unsafeBitCast(impl, to: IMP.self),
		                              ObjCMethodEncoding.forwardInvocation)

		assert(success)
		assert(ForwardInvocationTestObject.instancesRespond(to: ObjCSelector.forwardInvocation))

		let success2 = class_addMethod(ForwardInvocationTestObject.self,
		                               ForwardInvocationTestObject.forwardedSelector,
		                               _rac_objc_msgForward,
		                               ObjCMethodEncoding.forwardInvocation)

		assert(success2)
		assert(ForwardInvocationTestObject.instancesRespond(to: ForwardInvocationTestObject.forwardedSelector))
	}
}

@objc private protocol NSInvocationProtocol {
	var target: NSObject { get }
	var selector: Selector { get }

	func invoke()
}

private class InterceptedObjectSubclass: InterceptedObject {
	dynamic override func foo(_ number: Int, _ string: String) -> String {
		return "Subclass \(number) \(string)"
	}

	dynamic override func set(first: Any?, second: Any?) {
		DispatchQueue.main.async {
			super.set(first: first, second: second)
		}
	}
}

private class InterceptedObject: NSObject {
	var counter = 0
	@objc dynamic var hasInvokedSetObjectValueAndSecondObjectValue = false
	@objc dynamic var objectValue: Any?
	@objc dynamic var secondObjectValue: Any?

	@objc dynamic func increment() {
		counter += 1
	}

	@objc dynamic func foo(_ number: Int, _ string: String) -> String {
		return "Not Subclass \(number) \(string)"
	}

	@objc dynamic func lifeIsGood(_ value: Any?) {}
	@objc dynamic func set(first: Any?, second: Any?) {
		objectValue = first
		secondObjectValue = second
		
		hasInvokedSetObjectValueAndSecondObjectValue = true
	}
	
	@objc dynamic func testNumericValues(c: CChar, s: CShort, i: CInt, l: CLong, ll: CLongLong, uc: CUnsignedChar, us: CUnsignedShort, ui: CUnsignedInt, ul: CUnsignedLong, ull: CUnsignedLongLong, f: CFloat, d: CDouble, b: CBool) {}
	@objc dynamic func testReferences(nonnull: NSObject, nullable: NSObject?, iuo: NSObject!, class: AnyClass, nullableClass: AnyClass?, iuoClass: AnyClass!) {}
	@objc dynamic func testBridgedStructs(p: CGPoint, s: CGSize, r: CGRect, a: CGAffineTransform) {}
	@objc dynamic func testReturnValuesC(arg: CChar) -> CChar { return arg }
	@objc dynamic func testReturnValuesS(arg: CShort) -> CShort { return arg }
	@objc dynamic func testReturnValuesI(arg: CInt) -> CInt { return arg }
	@objc dynamic func testReturnValuesL(arg: CLong) -> CLong { return arg }
	@objc dynamic func testReturnValuesLL(arg: CLongLong) -> CLongLong { return arg }
	@objc dynamic func testReturnValuesUC(arg: CUnsignedChar) -> CUnsignedChar { return arg }
	@objc dynamic func testReturnValuesUS(arg: CUnsignedShort) -> CUnsignedShort { return arg }
	@objc dynamic func testReturnValuesUI(arg: CUnsignedInt) -> CUnsignedInt { return arg }
	@objc dynamic func testReturnValuesUL(arg: CUnsignedLong) -> CUnsignedLong { return arg }
	@objc dynamic func testReturnValuesULL(arg: CUnsignedLongLong) -> CUnsignedLongLong { return arg }
	@objc dynamic func testReturnValuesF(arg: CFloat) -> CFloat { return arg }
	@objc dynamic func testReturnValuesD(arg: CDouble) -> CDouble { return arg }
	@objc dynamic func testReturnValuesB(arg: CBool) -> CBool { return arg }
	@objc dynamic func testReturnValuesObject(arg: NSObject) -> NSObject { return arg }
	@objc dynamic func testReturnValuesObjectOptional(arg: NSObject?) -> NSObject? { return arg }
	@objc dynamic func testReturnValuesClass(arg: AnyClass) -> AnyClass { return arg }
}

fileprivate struct ReturnValueTest<I: Equatable> {
	var object: InterceptedObject
	var selector: Selector {
		switch I.self {
		case is CChar.Type:
			return #selector(InterceptedObject.testReturnValuesC(arg:))
		case is CShort.Type:
			return #selector(InterceptedObject.testReturnValuesS(arg:))
		case is CInt.Type:
			return #selector(InterceptedObject.testReturnValuesI(arg:))
		case is CLong.Type:
			return #selector(InterceptedObject.testReturnValuesL(arg:))
		case is CLongLong.Type:
			return #selector(InterceptedObject.testReturnValuesLL(arg:))
		case is CUnsignedChar.Type:
			return #selector(InterceptedObject.testReturnValuesUC(arg:))
		case is CUnsignedShort.Type:
			return #selector(InterceptedObject.testReturnValuesUS(arg:))
		case is CUnsignedInt.Type:
			return #selector(InterceptedObject.testReturnValuesUI(arg:))
		case is CUnsignedLong.Type:
			return #selector(InterceptedObject.testReturnValuesUL(arg:))
		case is CUnsignedLongLong.Type:
			return #selector(InterceptedObject.testReturnValuesULL(arg:))
		case is CFloat.Type:
			return #selector(InterceptedObject.testReturnValuesF(arg:))
		case is CDouble.Type:
			return #selector(InterceptedObject.testReturnValuesD(arg:))
		case is CBool.Type:
			return #selector(InterceptedObject.testReturnValuesB(arg:))
		case is NSObject.Type:
			return #selector(InterceptedObject.testReturnValuesObject(arg:))
		default:
			preconditionFailure("unsupported Type ReturnValueTest<\(I.self)>")
		}

	}

	init(object: InterceptedObject) {
		self.object = object
	}

	func argument(forOffset offset: UInt) -> I {
		switch I.self {
		case is CChar.Type:
			return (CChar.max - CChar(offset)) as! I
		case is CShort.Type:
			return (CShort.max - CShort(offset)) as! I
		case is CInt.Type:
			return (CInt.max - CInt(offset)) as! I
		case is CLong.Type:
			return (CLong.max - CLong(offset)) as! I
		case is CLongLong.Type:
			return (CLongLong.max - CLongLong(offset)) as! I
		case is CUnsignedChar.Type:
			return (CUnsignedChar.max - CUnsignedChar(offset)) as! I
		case is CUnsignedShort.Type:
			return (CUnsignedShort.max - CUnsignedShort(offset)) as! I
		case is CUnsignedInt.Type:
			return (CUnsignedInt.max - CUnsignedInt(offset)) as! I
		case is CUnsignedLong.Type:
			return (CUnsignedLong.max - CUnsignedLong(offset)) as! I
		case is CUnsignedLongLong.Type:
			return (CUnsignedLongLong.max - CUnsignedLongLong(offset)) as! I
		case is CFloat.Type:
			return (CFloat.greatestFiniteMagnitude - CFloat(offset)) as! I
		case is CDouble.Type:
			return (CDouble.greatestFiniteMagnitude - CDouble(offset)) as! I
		case is CBool.Type:
			return (offset % 2 == 0 ? true : false) as! I
		case is NSObject.Type:
			let bool = (offset % 2 == 0 ? true : false)
			return NSNumber(booleanLiteral: bool) as! I
		default:
			preconditionFailure("unsupported Type ReturnValueTest<\(I.self)>")
		}
	}

	func call(offset: UInt) {
		switch I.self {
		case is CChar.Type:
			let arg = CChar.max - CChar(offset)
			expect(self.object.testReturnValuesC(arg: arg)) == arg
		case is CShort.Type:
			let arg = argument(forOffset: offset) as! CShort
			expect(self.object.testReturnValuesS(arg: arg)) == arg
		case is CInt.Type:
			let arg = argument(forOffset: offset) as! CInt
			expect(self.object.testReturnValuesI(arg: arg)) == arg
		case is CLong.Type:
			let arg = argument(forOffset: offset) as! CLong
			expect(self.object.testReturnValuesL(arg: arg)) == arg
		case is CLongLong.Type:
			let arg = argument(forOffset: offset) as! CLongLong
			expect(self.object.testReturnValuesLL(arg: arg)) == arg
		case is CUnsignedChar.Type:
			let arg = argument(forOffset: offset) as! CUnsignedChar
			expect(self.object.testReturnValuesUC(arg: arg)) == arg
		case is CUnsignedShort.Type:
			let arg = argument(forOffset: offset) as! CUnsignedShort
			expect(self.object.testReturnValuesUS(arg: arg)) == arg
		case is CUnsignedInt.Type:
			let arg = argument(forOffset: offset) as! CUnsignedInt
			expect(self.object.testReturnValuesUI(arg: arg)) == arg
		case is CUnsignedLong.Type:
			let arg = argument(forOffset: offset) as! CUnsignedLong
			expect(self.object.testReturnValuesUL(arg: arg)) == arg
		case is CUnsignedLongLong.Type:
			let arg = argument(forOffset: offset) as! CUnsignedLongLong
			expect(self.object.testReturnValuesULL(arg: arg)) == arg
		case is CFloat.Type:
			let arg = argument(forOffset: offset) as! CFloat
			expect(self.object.testReturnValuesF(arg: arg)) == arg
		case is CDouble.Type:
			let arg = argument(forOffset: offset) as! CDouble
			expect(self.object.testReturnValuesD(arg: arg)) == arg
		case is CBool.Type:
			let arg = argument(forOffset: offset) as! CBool
			expect(self.object.testReturnValuesB(arg: arg)) == arg
		case is NSObject.Type:
			let arg = argument(forOffset: offset) as! NSObject
			expect(self.object.testReturnValuesObject(arg: arg)) == arg
		default:
			fail("unsupported Type ReturnValueTest<\(I.self)>")
		}
	}

	func validate(arg: I, offset: UInt) {
		expect(arg) == argument(forOffset: offset)
	}

	func validateAll(arguments: [Any?], offset: UInt) {
		validate(arg: arguments[0] as! I, offset: offset)
		validate(arg: arguments[1] as! I, offset: offset)
	}

	func test() {
		let signal = object.reactive.signal(for:selector,
											includeReturnValue:true)

		var arguments = [[Any?]]()
		signal.observeValues { arguments.append($0) }

		expect(arguments.count) == 0

		call(offset: 0)
		expect(arguments.count) == 1
		validateAll(arguments: arguments[0], offset: 0)

		call(offset: 1)
		expect(arguments.count) == 2
		validateAll(arguments: arguments[1], offset: 1)
	}

}


