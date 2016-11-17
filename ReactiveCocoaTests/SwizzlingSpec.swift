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

				let subclass = Swizzler.swizzleClass(of: object)
				expect(type(of: object)).to(beIdenticalTo(subclass.reference))

				let objcClass = (object as AnyObject).objcClass
				expect(objcClass).to(beIdenticalTo(SwizzledObject.self))
				expect((objcClass as AnyObject).objcClass).to(beIdenticalTo(SwizzledObject.self))

				expect(subclass.name).to(contain("_RACSwift"))
			}

			it("should reuse the runtime subclass across instances") {
				let object = SwizzledObject()
				let subclass = Swizzler.swizzleClass(of: object)

				let object2 = SwizzledObject()
				let subclass2 = Swizzler.swizzleClass(of: object2)

				expect(subclass) == subclass2
			}

			it("should return the known runtime subclass") {
				let object = SwizzledObject()
				let subclass = Swizzler.swizzleClass(of: object)
				let subclass2 = Swizzler.swizzleClass(of: object)

				expect(subclass) == subclass2
			}
		}
	}
}
