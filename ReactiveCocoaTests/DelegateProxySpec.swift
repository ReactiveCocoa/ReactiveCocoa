import Quick
import Nimble
import enum Result.NoError
import ReactiveSwift
@testable import ReactiveCocoa

@objc protocol ObjectDelegate: NSObjectProtocol {
	func foo()
	@objc optional func bar()
	@objc optional func nop()
}

class Object: NSObject {
	var delegateSetCount = 0
	var delegateSelectors: [Selector] = []

	weak var delegate: ObjectDelegate? {
		didSet {
			delegateSetCount += 1
			delegateSelectors = Array()

			if delegate?.responds(to: #selector(ObjectDelegate.foo)) ?? false {
				delegateSelectors.append(#selector(ObjectDelegate.foo))
			}

			if delegate?.responds(to: #selector(ObjectDelegate.bar)) ?? false {
				delegateSelectors.append(#selector(ObjectDelegate.bar))
			}

			if delegate?.responds(to: #selector(ObjectDelegate.nop)) ?? false {
				delegateSelectors.append(#selector(ObjectDelegate.nop))
			}
		}
	}

	deinit {
		// Mimic the behavior of clearing delegates of some Cocoa classes.
		delegate = nil
	}
}

class ObjectDelegateCounter: NSObject, ObjectDelegate {
	var fooCounter = 0
	var nopCounter = 0

	func foo() {
		fooCounter += 1
	}

	func nop() {
		nopCounter += 1
	}
}

class ObjectDelegateProxy: DelegateProxy<ObjectDelegate>, ObjectDelegate {
	func foo() {
		forwardee?.foo()
	}

	func bar() {
		forwardee?.bar?()
	}
}

class DelegateProxySpec: QuickSpec {
	override func spec() {
		describe("DelegateProxy") {
			var object: Object!
			var proxy: DelegateProxy<ObjectDelegate>!

			beforeEach {
				object = Object()
				proxy = ObjectDelegateProxy.proxy(for: object,
				                                  setter: #selector(setter: object.delegate),
				                                  getter: #selector(getter: object.delegate))
			}

			afterEach {
				weak var weakObject = object

				object = nil
				expect(weakObject).to(beNil())
			}

			it("should be automatically set as the object's delegate.") {
				expect(object.delegate).to(beIdenticalTo(proxy))
			}

			it("should respond to the protocol requirement checks.") {
				expect(proxy.responds(to: #selector(ObjectDelegate.foo))) == true
				expect(proxy.responds(to: #selector(ObjectDelegate.bar))) == true
				expect(proxy.responds(to: #selector(ObjectDelegate.nop))) == false
			}

			it("should complete its signals when the object deinitializes") {
				var isCompleted = false

				let foo: Signal<(), NoError> = proxy.intercept(#selector(ObjectDelegate.foo))
				foo.observeCompleted { isCompleted = true }

				expect(isCompleted) == false

				object = nil
				expect(isCompleted) == true
			}

			it("should interrupt the observers if the object has already deinitialized") {
				var isInterrupted = false

				object = nil

				let foo: Signal<(), NoError> = proxy.intercept(#selector(ObjectDelegate.foo))
				foo.observeInterrupted { isInterrupted = true }

				expect(isInterrupted) == true
			}

			it("should emit a `value` event whenever any delegate method is invoked.") {
				var fooCount = 0
				var barCount = 0

				let foo: Signal<(), NoError> = proxy.intercept(#selector(ObjectDelegate.foo))
				foo.observeValues { fooCount += 1 }

				let bar: Signal<(), NoError> = proxy.intercept(#selector(ObjectDelegate.bar))
				bar.observeValues { barCount += 1 }

				expect(fooCount) == 0
				expect(barCount) == 0

				object.delegate?.foo()
				object.delegate?.bar?()
				expect(fooCount) == 1
				expect(barCount) == 1

				object.delegate?.foo()
				expect(fooCount) == 2

				object.delegate?.bar?()
				expect(barCount) == 2
			}

			it("should accomodate forwardee changes when responding to the protocol requirement checks.") {
				expect(proxy.responds(to: #selector(ObjectDelegate.nop))) == false

				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee
				expect(proxy.responds(to: #selector(ObjectDelegate.nop))) == true

				proxy.forwardee = nil
				expect(proxy.responds(to: #selector(ObjectDelegate.nop))) == false
			}

			it("should invoke the method on the forwardee.") {
				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee

				var fooCount = 0

				let foo: Signal<(), NoError> = proxy.intercept(#selector(ObjectDelegate.foo))
				foo.observeValues { fooCount += 1 }

				expect(fooCount) == 0
				expect(forwardee.fooCounter) == 0

				object.delegate?.foo()
				expect(fooCount) == 1
				expect(forwardee.fooCounter) == 1

				object.delegate?.foo()
				expect(fooCount) == 2
				expect(forwardee.fooCounter) == 2
			}

			it("should emit a `value` event for an optional requirement even if the forwardee does not implement it.") {
				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee

				var barCount = 0

				let bar: Signal<(), NoError> = proxy.intercept(#selector(ObjectDelegate.bar))
				bar.observeValues { barCount += 1 }

				object.delegate?.bar?()
				expect(barCount) == 1
			}

			it("should invoke an optional requirement on the forwardee even if it does not implement it.") {
				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee

				expect(forwardee.nopCounter) == 0

				object.delegate?.nop?()
				expect(forwardee.nopCounter) == 1
			}

			it("should invoke the original delegate setter whenever the forwardee is updated.") {
				// The expected initial count is accounted for the proxy setup.
				expect(object.delegateSetCount) == 1
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.bar)]

				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee
				expect(object.delegateSetCount) == 2
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.bar), #selector(ObjectDelegate.nop)]
				expect(object.delegate).to(beIdenticalTo(proxy))

				proxy.forwardee = nil
				expect(object.delegateSetCount) == 3
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.bar)]
				expect(object.delegate).to(beIdenticalTo(proxy))
			}
		}
	}
}
