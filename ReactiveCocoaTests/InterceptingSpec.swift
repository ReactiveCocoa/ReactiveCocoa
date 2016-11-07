import Foundation
import ReactiveCocoa
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

			it("should send a value when the selector is invoked without implementation") {
				let selector = #selector(TestProtocol.optionalMethod)

				let signal = object.reactive.trigger(for: selector,
				                                     from: TestProtocol.self)
				expect(object.responds(to: selector)) == true

				var counter = 0
				signal.observeValues { counter += 1 }

				expect(counter) == 0

				(object as TestProtocol).optionalMethod!()
				expect(counter) == 1

				(object as TestProtocol).optionalMethod!()
				expect(counter) == 2
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

					DispatchQueue.global(priority: .high).async {
						_ = object.reactive.trigger(for: #selector(object.increment))

						DispatchQueue.global(priority: .high).async {
							_ = object.reactive.trigger(for: #selector(object.increment))

							isDeadlocked = false
						}
					}

					expect(isDeadlocked).toEventually(beFalsy())
				}
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

			it("should send a value when the selector is invoked without implementation") {
				let selector = #selector(TestProtocol.optionalMethod)

				let signal = object.reactive.signal(for: selector,
				                                    from: TestProtocol.self)
				expect(object.responds(to: selector)) == true

				var counter = 0
				signal.observeValues { _ in counter += 1 }

				expect(counter) == 0

				(object as TestProtocol).optionalMethod!()
				expect(counter) == 1

				(object as TestProtocol).optionalMethod!()
				expect(counter) == 2
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

@objc protocol TestProtocol {
	@objc optional func optionalMethod()
}

class InterceptedObject: NSObject, TestProtocol {
	var counter = 0

	dynamic func increment() {
		counter += 1
	}
	
	dynamic func testNumericValues(c: CChar, s: CShort, i: CInt, l: CLong, ll: CLongLong, uc: CUnsignedChar, us: CUnsignedShort, ui: CUnsignedInt, ul: CUnsignedLong, ull: CUnsignedLongLong, f: CFloat, d: CDouble, b: CBool) {}
	dynamic func testReferences(nonnull: NSObject, nullable: NSObject?, iuo: NSObject!, class: AnyClass, nullableClass: AnyClass?, iuoClass: AnyClass!) {}
	dynamic func testBridgedStructs(p: CGPoint, s: CGSize, r: CGRect, a: CGAffineTransform) {}
}
