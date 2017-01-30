import Foundation
@testable import ReactiveCocoa
import ReactiveSwift
import enum Result.NoError
import Quick
import Nimble
import CoreGraphics

class InterceptingSpec: QuickSpec {
	override func spec() {
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()
					.dispose()

				object.reactive
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()
					.dispose()

				object.reactive.trigger(for: #selector(setter: InterceptedObject.objectValue))
					.observeValues { counter += 1 }

				object.reactive
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				_ = object.reactive.trigger(for: #selector(object.lifeIsGood))

				let swizzledSelector = #selector(object.lifeIsGood)

				// Redirect `swizzledSelector` to the forwarding machinery.
				let method = class_getInstanceMethod(originalClass, swizzledSelector)!
				let typeEncoding = method_getTypeEncoding(method)

				let original = class_replaceMethod(originalClass,
				                                   swizzledSelector,
				                                   _rac_objc_msgForward,
				                                   typeEncoding)
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
				                                    typeEncoding2)
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
				                                   typeEncoding)
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
				                                    typeEncoding2)
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

				let lifeIsGoodBlock: @convention(block) (AnyObject, AnyObject) -> Void = { _ in
					expect(invoked) == false
					invoked = true
				}

				let method = class_getInstanceMethod(originalClass, swizzledSelector)!
				let typeEncoding = method_getTypeEncoding(method)

				let original = class_replaceMethod(originalClass,
				                                   swizzledSelector,
				                                   imp_implementationWithBlock(lifeIsGoodBlock as Any),
				                                   typeEncoding)
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
			var superclassTuple: [Any?]?

			var subclassObj: InterceptedObjectSubclass!
			var subclassTuple: [Any?]?

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
						superclassTuple = args
				}

				subclassObj
					.reactive
					.signal(for: #selector(InterceptedObject.foo))
					.observeValues { args in
						subclassTuple = args
				}

				expect(superclassObj.foo(40, "foo")) == "Not Subclass 40 foo"

				let expectedValues = [40, "foo"] as NSArray
				expect(superclassTuple as NSArray?) == expectedValues

				expect(subclassObj.foo(40, "foo")) == "Subclass 40 foo"

				expect(subclassTuple as NSArray?) == expectedValues
			}

			it("should not collide when the superclass is invoked asynchronously") {
				superclassObj.reactive
					.signal(for: #selector(InterceptedObject.set(first:second:)))
					.observeValues { args in
						superclassTuple = args
				}

				subclassObj
					.reactive
					.signal(for: #selector(InterceptedObject.set(first:second:)))
					.observeValues { args in
						subclassTuple = args
				}

				superclassObj.set(first: "foo", second:"42")
				expect(superclassObj.hasInvokedSetObjectValueAndSecondObjectValue) == true

				let expectedValues = ["foo", "42"] as NSArray
				expect(superclassTuple as NSArray?) == expectedValues

				subclassObj.set(first: "foo", second:"42")
				expect(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue) == false
				expect(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue).toEventually(beTruthy())

				expect(subclassTuple as NSArray?) == expectedValues
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
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
					.start()

				expect((object as AnyObject).objcClass).to(beIdenticalTo(originalClass))
			}

			it("should report the original class when it's KVO'd before dynamically subclassing") {
				object.reactive
					.values(forKeyPath: #keyPath(InterceptedObject.objectValue))
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
					expect(arguments[0] as? CChar) == CChar.max - CChar(offset)
					expect(arguments[1] as? CShort) == CShort.max - CShort(offset)
					expect(arguments[2] as? CInt) == CInt.max - CInt(offset)
					expect(arguments[3] as? CLong) == CLong.max - CLong(offset)
					expect(arguments[4] as? CLongLong) == CLongLong.max - CLongLong(offset)
					expect(arguments[5] as? CUnsignedChar) == CUnsignedChar.max - CUnsignedChar(offset)
					expect(arguments[6] as? CUnsignedShort) == CUnsignedShort.max - CUnsignedShort(offset)
					expect(arguments[7] as? CUnsignedInt) == CUnsignedInt.max - CUnsignedInt(offset)
					expect(arguments[8] as? CUnsignedLong) == CUnsignedLong.max - CUnsignedLong(offset)
					expect(arguments[9] as? CUnsignedLongLong) == CUnsignedLongLong.max - CUnsignedLongLong(offset)
					expect(arguments[10] as? CFloat) == CFloat.greatestFiniteMagnitude - CFloat(offset)
					expect(arguments[11] as? CDouble) == CDouble.greatestFiniteMagnitude - CDouble(offset)
					expect(arguments[12] as? CBool) == (offset % 2 == 0 ? true : false)
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
					expect((arguments[0] as! CGPoint)) == CGPoint(x: offset, y: offset)
					expect((arguments[1] as! CGSize)) == CGSize(width: offset, height: offset)
					expect((arguments[2] as! CGRect)) == CGRect(x: offset, y: offset, width: offset, height: offset)
					expect((arguments[3] as! CGAffineTransform)) == CGAffineTransform(translationX: offset, y: offset)
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
	}
}

private class ForwardInvocationTestObject: InterceptedObject {
	static let forwardedSelector = Selector((("forwarded")))

	var forwardedCount = 0
	var forwardedSelector: Selector?

	override open class func initialize() {
		struct Static {
			static var token: Int = {
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

				return 0
			}()
		}

		_ = Static.token
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
	dynamic var hasInvokedSetObjectValueAndSecondObjectValue = false
	dynamic var objectValue: Any?
	dynamic var secondObjectValue: Any?

	dynamic func increment() {
		counter += 1
	}

	dynamic func foo(_ number: Int, _ string: String) -> String {
		return "Not Subclass \(number) \(string)"
	}

	dynamic func lifeIsGood(_ value: Any?) {}
	dynamic func set(first: Any?, second: Any?) {
		objectValue = first
		secondObjectValue = second
		
		hasInvokedSetObjectValueAndSecondObjectValue = true
	}
	
	dynamic func testNumericValues(c: CChar, s: CShort, i: CInt, l: CLong, ll: CLongLong, uc: CUnsignedChar, us: CUnsignedShort, ui: CUnsignedInt, ul: CUnsignedLong, ull: CUnsignedLongLong, f: CFloat, d: CDouble, b: CBool) {}
	dynamic func testReferences(nonnull: NSObject, nullable: NSObject?, iuo: NSObject!, class: AnyClass, nullableClass: AnyClass?, iuoClass: AnyClass!) {}
	dynamic func testBridgedStructs(p: CGPoint, s: CGSize, r: CGRect, a: CGAffineTransform) {}
}
