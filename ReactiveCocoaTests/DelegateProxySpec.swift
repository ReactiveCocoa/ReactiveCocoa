import Foundation
import Quick
import Nimble
import ReactiveSwift
@testable import ReactiveCocoa

@objc private protocol ObjectDelegate: NSObjectProtocol {
	func foo()
	@objc optional func bar()
	@objc optional func nop()
}

@objc internal protocol InternalObjectDelegate: NSObjectProtocol {
	func foo()
}

@objc public protocol PublicObjectDelegate: NSObjectProtocol {
	func foo()
}

private class RemanglingTestHelper: NSObject {
	@objc dynamic weak var privateDelegate: ObjectDelegate?
	@objc dynamic weak var internalDelegate: InternalObjectDelegate?
	@objc dynamic weak var publicDelegate: PublicObjectDelegate?
}

private class Object: NSObject {
	@objc var delegateSetCount = 0
	var delegateSelectors: [Selector] = []

	@objc dynamic weak var delegate: ObjectDelegate? {
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

private class ObjectDelegateCounter: NSObject, ObjectDelegate {
	var fooCounter = 0
	var nopCounter = 0

	func foo() {
		fooCounter += 1
	}

	func nop() {
		nopCounter += 1
	}
}

@objc private protocol ArbitraryReturningDelegate: NSObjectProtocol {
	func foo() -> Int
	func bar() -> Double
	func nop()
}

private class ArbitraryReturningCounter: NSObject, ArbitraryReturningDelegate {
	var fooCounter = 0
	var barCounter = 0
	var nopCounter = 0

	func foo() -> Int {
		fooCounter += 1
		return 1024
	}

	func bar() -> Double {
		barCounter += 1
		return 1024.0
	}

	func nop() {
		nopCounter += 1
	}
}

private class ArbitraryReturningTestHelper: NSObject {
	@objc dynamic weak var delegate: ArbitraryReturningDelegate?
}

class DelegateProxySpec: QuickSpec {
	override func spec() {
		describe("DelegateProxy") {
			var object: Object!
			var proxy: DelegateProxy<ObjectDelegate>!

			beforeEach {
				object = Object()
				proxy = object.reactive.proxy(keyPath: \.delegate)
			}

			afterEach {
				weak var weakObject = object
				weak var weakProxy = proxy

				autoreleasepool {
					object = nil
					proxy = nil
				}

				expect(weakObject).to(beNil())
				expect(weakProxy).to(beNil())
			}

			it("should respond to the protocol requirement checks.") {
				expect(proxy.conforms(to: ObjectDelegate.self)) == true
				expect(proxy.responds(to: #selector(ObjectDelegate.foo))) == true
				expect(proxy.responds(to: #selector(ObjectDelegate.bar))) == false
				expect(proxy.responds(to: #selector(ObjectDelegate.nop))) == false
			}

			it("should create proxies without issue") {
				let testHelper = RemanglingTestHelper()
				let _: DelegateProxy<ObjectDelegate> = testHelper.reactive.proxy(keyPath: \.privateDelegate)
				let _: DelegateProxy<InternalObjectDelegate> = testHelper.reactive.proxy(keyPath: \.internalDelegate)
				let _: DelegateProxy<PublicObjectDelegate> = testHelper.reactive.proxy(keyPath: \.publicDelegate)
			}

			it("should be automatically set as the object's delegate.") {
				expect(object.delegate).to(beIdenticalTo(proxy))
			}

			it("should not retain the delegate") {
				var counter: ObjectDelegateCounter? = ObjectDelegateCounter()
				weak var weakCounter = counter
				proxy.forwardee = counter

				object.delegate?.foo()
				expect(counter?.fooCounter) == 1

				autoreleasepool {
					counter = nil
				}

				expect(weakCounter).to(beNil())
			}

			it("should not be erased when the delegate is set with a new one.") {
				object.delegate = nil
				expect(object.delegate).to(beIdenticalTo(proxy))
				expect(proxy.forwardee).to(beNil())

				let counter = ObjectDelegateCounter()
				object.delegate = counter
				expect(object.delegate).to(beIdenticalTo(proxy))
				expect(proxy.forwardee).to(beIdenticalTo(counter))
			}

			it("should complete its signals when the object deinitializes") {
				var isCompleted = false

				let foo: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.foo))
				foo.observeCompleted { isCompleted = true }

				expect(isCompleted) == false

				object = nil
				expect(isCompleted) == true
			}

			it("should interrupt the observers if the object has already deinitialized") {
				var isInterrupted = false

				object = nil

				let foo: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.foo))
				foo.observeInterrupted { isInterrupted = true }

				expect(isInterrupted) == true
			}

			it("should emit a `value` event whenever any delegate method is invoked.") {
				var fooCount = 0
				var barCount = 0

				let foo: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.foo))
				foo.observeValues { fooCount += 1 }

				let bar: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.bar))
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

				let foo: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.foo))
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

				let bar: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.bar))
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
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo)]

				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee
				expect(object.delegateSetCount) == 2
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.nop)]
				expect(object.delegate).to(beIdenticalTo(proxy))

				proxy.forwardee = nil
				expect(object.delegateSetCount) == 3
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo)]
				expect(object.delegate).to(beIdenticalTo(proxy))
			}

			it("should not have proxies of the same delegate type intervening with each other.") {
				let anotherObject = Object()
				let anotherProxy: DelegateProxy<ObjectDelegate> = anotherObject.reactive.proxy(keyPath: \.delegate)

				// The expected initial count is accounted for the proxy setup.
				expect(object.delegateSetCount) == 1
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo)]
				expect(anotherObject.delegateSetCount) == 1
				expect(anotherObject.delegateSelectors) == [#selector(ObjectDelegate.foo)]

				let forwardee = ObjectDelegateCounter()
				proxy.forwardee = forwardee

				expect(object.delegateSetCount) == 2
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.nop)]
				expect(object.delegate).to(beIdenticalTo(proxy))
				expect(anotherObject.delegateSetCount) == 1
				expect(anotherObject.delegateSelectors) == [#selector(ObjectDelegate.foo)]
				expect(anotherObject.delegate).to(beIdenticalTo(anotherProxy))

				let forwardee2 = ObjectDelegateCounter()
				anotherProxy.forwardee = forwardee2

				expect(object.delegateSetCount) == 2
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.nop)]
				expect(object.delegate).to(beIdenticalTo(proxy))
				expect(anotherObject.delegateSetCount) == 2
				expect(anotherObject.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.nop)]
				expect(anotherObject.delegate).to(beIdenticalTo(anotherProxy))

				proxy.forwardee = nil

				expect(object.delegateSetCount) == 3
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo)]
				expect(object.delegate).to(beIdenticalTo(proxy))
				expect(anotherObject.delegateSetCount) == 2
				expect(anotherObject.delegateSelectors) == [#selector(ObjectDelegate.foo), #selector(ObjectDelegate.nop)]
				expect(anotherObject.delegate).to(beIdenticalTo(anotherProxy))

				anotherProxy.forwardee = nil

				expect(object.delegateSetCount) == 3
				expect(object.delegateSelectors) == [#selector(ObjectDelegate.foo)]
				expect(object.delegate).to(beIdenticalTo(proxy))
				expect(anotherObject.delegateSetCount) == 3
				expect(anotherObject.delegateSelectors) == [#selector(ObjectDelegate.foo)]
				expect(anotherObject.delegate).to(beIdenticalTo(anotherProxy))
			}

			describe("interoperability") {
				var object: Object!
				var proxy: DelegateProxy<ObjectDelegate>!
				var fooCounter = 0
				
				beforeEach {
					object = Object()
					fooCounter = 0
				}

				func setProxy() {
					proxy = object.reactive.proxy(keyPath: \.delegate)

					let signal: Signal<(), Never> = proxy.trigger(for: #selector(ObjectDelegate.foo))
                    signal.observeValues { fooCounter += 1 }
				}

				it("should not affect instances sharing the same runtime subclass") {
					_ = object.reactive.producer(forKeyPath: #keyPath(Object.delegateSetCount)).start()
					setProxy()
					expect(object.delegate).to(beIdenticalTo(proxy))

					// Another object without RAC swizzling.
					let object2 = Object()
					_ = object2.reactive.producer(forKeyPath: #keyPath(Object.delegateSetCount)).start()

					expect(object.objcClass).to(beIdenticalTo(object2.objcClass))

					let className = NSStringFromClass(object_getClass(object)!)
					expect(className).to(beginWith("NSKVONotifying_"))
					expect(className).toNot(endWith("_RACSwift"))

					let delegate = ObjectDelegateCounter()
					object2.delegate = delegate
					expect(object2.delegate).to(beIdenticalTo(delegate))
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by KVO.") {
					_ = object.reactive.producer(forKeyPath: #keyPath(Object.delegateSetCount)).start()
					expect(object.delegate).to(beNil())

					setProxy()
					expect(object.delegate).to(beIdenticalTo(proxy))

					object.delegate?.foo()
					expect(fooCounter) == 1

					object.delegate = nil
					expect(object.delegate).to(beIdenticalTo(proxy))

					object.delegate?.foo()
					expect(fooCounter) == 2
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by RAC.") {
					_ = object.reactive.trigger(for: #selector(getter: Object.delegateSetCount))
					expect(object.delegate).to(beNil())

					setProxy()
					expect(object.delegate).to(beIdenticalTo(proxy))

					object.delegate?.foo()
					expect(fooCounter) == 1

					object.delegate = nil
					expect(object.delegate).to(beIdenticalTo(proxy))

					object.delegate?.foo()
					expect(fooCounter) == 2
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by RAC for intercepting the delegate setter.") {
					var counter = 0

					object.reactive
						.trigger(for: #selector(setter: Object.delegate))
						.observeValues { counter += 1 }
					expect(object.delegate).to(beNil())

					setProxy()

					// The assignment of the proxy should not be captured by the method
					// interception logic.
					expect(object.delegate).to(beIdenticalTo(proxy))
					expect(counter) == 0

					object.delegate?.foo()
					expect(fooCounter) == 1

					object.delegate = nil
					expect(object.delegate).to(beIdenticalTo(proxy))
					expect(counter) == 1

					object.delegate?.foo()
					expect(fooCounter) == 2
				}

				it("should be automatically set as the object's delegate even if it is subsequently isa-swizzled by RAC for intercepting the delegate setter.") {
					expect(object.delegate).to(beNil())

					setProxy()
					expect(object.delegate).to(beIdenticalTo(proxy))

					object.delegate?.foo()
					expect(fooCounter) == 1

					var counter = 0

					object.reactive
						.trigger(for: #selector(setter: Object.delegate))
						.observeValues { counter += 1 }

					object.delegate = nil
					expect(object.delegate).to(beIdenticalTo(proxy))
					expect(counter) == 1

					object.delegate?.foo()
					expect(fooCounter) == 2
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by KVO for observing the delegate key path.") {
					var counter = 0

					object.reactive
						.signal(forKeyPath: #keyPath(Object.delegate))
						.observeValues { _ in counter += 1 }
					expect(object.delegate).to(beNil())

					setProxy()

					// The assignment of the proxy should not be captured by KVO.
					expect(object.delegate).to(beIdenticalTo(proxy))
					expect(counter) == 0

					object.delegate?.foo()
					expect(fooCounter) == 1

					object.delegate = nil
					expect(object.delegate).to(beIdenticalTo(proxy))
					expect(counter) == 0

					object.delegate?.foo()
					expect(fooCounter) == 2
				}

				it("should be automatically set as the object's delegate even if it is subsequently isa-swizzled by KVO for observing the delegate key path.") {
					expect(object.delegate).to(beNil())

					setProxy()
					expect(object.delegate).to(beIdenticalTo(proxy))

					object.delegate?.foo()
					expect(fooCounter) == 1

					var counter = 0

					object.reactive
						.signal(forKeyPath: #keyPath(Object.delegate))
						.observeValues { _ in counter += 1 }

					object.delegate = nil
					expect(object.delegate).to(beIdenticalTo(proxy))
					expect(counter) == 1

					object.delegate?.foo()
					expect(fooCounter) == 2
				}
			}
		}
	}
}
