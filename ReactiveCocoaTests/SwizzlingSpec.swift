@testable import ReactiveCocoa
import Quick
import Nimble

class SwizzledObject: NSObject {}

class SwizzlingSpec: QuickSpec {
	override func spec() {
		describe("runtime subclassing") {
			it("should swizzle the instance while still reporting the perceived class in `-class` and `+class`") {
				let object = SwizzledObject()
				expect(type(of: object)).to(beIdenticalTo(SwizzledObject.self))

				let subclass: AnyClass = swizzleClass(object)
				expect(type(of: object)).to(beIdenticalTo(subclass))

				let objcClass = (object as AnyObject).objcClass
				expect(objcClass).to(beIdenticalTo(SwizzledObject.self))
				expect((objcClass as AnyObject).objcClass).to(beIdenticalTo(SwizzledObject.self))

				expect(String(cString: class_getName(subclass))).to(contain("_RACSwift"))
			}

			it("should reuse the runtime subclass across instances") {
				let object = SwizzledObject()
				let subclass: AnyClass = swizzleClass(object)

				let object2 = SwizzledObject()
				let subclass2: AnyClass = swizzleClass(object2)

				expect(subclass).to(beIdenticalTo(subclass2))
			}

			it("should return the known runtime subclass") {
				let object = SwizzledObject()
				let subclass: AnyClass = swizzleClass(object)
				let subclass2: AnyClass = swizzleClass(object)

				expect(subclass).to(beIdenticalTo(subclass2))
			}
		}
	}
}
