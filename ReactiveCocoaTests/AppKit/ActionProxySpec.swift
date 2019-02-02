import Quick
import Nimble
import enum Result.NoError
import ReactiveSwift
@testable import ReactiveCocoa

private class Object: NSObject, ActionMessageSending {
	@objc dynamic var objectValue: AnyObject? = nil

	@objc dynamic weak var target: AnyObject?
	@objc dynamic var action: Selector?

	deinit {
		target = nil
		action = nil
	}
}

private class Receiver: NSObject {
	var counter = 0

	@objc func foo() {
		counter += 1
	}
}

class ActionProxySpec: QuickSpec {
	override func spec() {
		describe("ActionProxy") {
			var object: Object!
			var proxy: ActionProxy<Object>!

			beforeEach {
				object = Object()
				proxy = object.reactive.proxy
			}

			afterEach {
				weak var weakObject = object

				object = nil
				expect(weakObject).to(beNil())
			}

			func sendMessage() {
				_ = object.action.map { object.target?.perform($0, with: nil) }
			}

			it("should be automatically set as the object's delegate.") {
				expect(object.target).to(beIdenticalTo(proxy))
				expect(object.action) == #selector(proxy.invoke(_:))
			}

			it("should not be erased when the delegate is set with a new one.") {
				object.target = nil
				object.action = nil

				expect(object.target).to(beIdenticalTo(proxy))
				expect(object.action) == #selector(proxy.invoke(_:))

				expect(proxy.target).to(beNil())
				expect(proxy.action).to(beNil())

				let counter = Receiver()
				object.target = counter
				object.action = #selector(counter.foo)

				expect(object.target).to(beIdenticalTo(proxy))
				expect(object.action) == #selector(proxy.invoke(_:))

				expect(proxy.target).to(beIdenticalTo(counter))
				expect(proxy.action) == #selector(counter.foo)
			}

			it("should complete its signals when the object deinitializes") {
				var isCompleted = false
				proxy.invoked.observeCompleted { isCompleted = true }

				expect(isCompleted) == false

				object = nil
				expect(isCompleted) == true
			}

			it("should interrupt the observers if the object has already deinitialized") {
				object = nil

				var isInterrupted = false
				proxy.invoked.observeInterrupted { isInterrupted = true }

				expect(isInterrupted) == true
			}

			it("should emit a `value` event whenever an action message is sent.") {
				var fooCount = 0
				proxy.invoked.observeValues { _ in fooCount += 1 }

				expect(fooCount) == 0

				sendMessage()
				expect(fooCount) == 1

				sendMessage()
				expect(fooCount) == 2
			}

			it("should pass through the action message to the forwardee.") {
				let receiver = Receiver()
				proxy.target = receiver
				proxy.action = #selector(receiver.foo)

				var fooCount = 0
				proxy.invoked.observeValues { _ in fooCount += 1 }

				expect(fooCount) == 0
				expect(receiver.counter) == 0

				sendMessage()
				expect(fooCount) == 1
				expect(receiver.counter) == 1

				sendMessage()
				expect(fooCount) == 2
				expect(receiver.counter) == 2
			}

			describe("interoperability") {
				var object: Object!
				var proxy: ActionProxy<Object>!
				var invocationCount = 0

				beforeEach {
					object = Object()
					invocationCount = 0
				}

				func setProxy() {
					proxy = object.reactive.proxy
					proxy.invoked.observeValues { _ in invocationCount += 1 }
				}

				func sendMessage() {
					_ = object.action.map { object.target?.perform($0, with: nil) }
				}

				it("should not affect instances sharing the same runtime subclass") {
					_ = object.reactive.producer(forKeyPath: #keyPath(Object.objectValue)).start()
					setProxy()
					expect(object.target).to(beIdenticalTo(proxy))

					// Another object without RAC swizzling.
					let object2 = Object()
					_ = object2.reactive.producer(forKeyPath: #keyPath(Object.objectValue)).start()

					expect(object.objcClass).to(beIdenticalTo(object2.objcClass))

					let className = NSStringFromClass(object_getClass(object)!)
					expect(className).to(beginWith("NSKVONotifying_"))
					expect(className).toNot(endWith("_RACSwift"))

					object2.target = object
					object2.action = #selector(AnyObject.perform(_:with:))

					expect(object2.target).to(beIdenticalTo(object))
					expect(object2.action) == #selector(AnyObject.perform(_:with:))
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by KVO.") {
					_ = object.reactive.producer(forKeyPath: #keyPath(Object.objectValue)).start()
					expect(object.target).to(beNil())

					setProxy()
					expect(object.target).to(beIdenticalTo(proxy))

					sendMessage()
					expect(invocationCount) == 1

					object.target = nil
					expect(object.target).to(beIdenticalTo(proxy))

					sendMessage()
					expect(invocationCount) == 2
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by RAC.") {
					_ = object.reactive.trigger(for: #selector(getter: Object.objectValue))
					expect(object.target).to(beNil())

					setProxy()
					expect(object.target).to(beIdenticalTo(proxy))

					sendMessage()
					expect(invocationCount) == 1

					object.target = nil
					expect(object.target).to(beIdenticalTo(proxy))

					sendMessage()
					expect(invocationCount) == 2
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by RAC for intercepting the delegate setter.") {
					var counter = 0

					object.reactive
						.trigger(for: #selector(setter: Object.target))
						.observeValues { counter += 1 }
					expect(object.target).to(beNil())

					setProxy()

					// The assignment of the proxy should not be captured by the method
					// interception logic.
					expect(object.target).to(beIdenticalTo(proxy))
					expect(counter) == 0

					sendMessage()
					expect(invocationCount) == 1

					object.target = nil
					expect(object.target).to(beIdenticalTo(proxy))
					expect(counter) == 1

					sendMessage()
					expect(invocationCount) == 2
				}

				it("should be automatically set as the object's delegate even if it is subsequently isa-swizzled by RAC for intercepting the delegate setter.") {
					expect(object.target).to(beNil())

					setProxy()
					expect(object.target).to(beIdenticalTo(proxy))

					sendMessage()
					expect(invocationCount) == 1

					var counter = 0

					object.reactive
						.trigger(for: #selector(setter: Object.target))
						.observeValues { counter += 1 }

					object.target = nil
					expect(object.target).to(beIdenticalTo(proxy))
					expect(counter) == 1

					sendMessage()
					expect(invocationCount) == 2
				}

				it("should be automatically set as the object's delegate even if it has already been isa-swizzled by KVO for observing the delegate key path.") {
					var counter = 0

					object.reactive
						.signal(forKeyPath: #keyPath(Object.target))
						.observeValues { _ in counter += 1 }
					expect(object.target).to(beNil())

					setProxy()

					// The assignment of the proxy should not be captured by KVO.
					expect(object.target).to(beIdenticalTo(proxy))
					expect(counter) == 0

					sendMessage()
					expect(invocationCount) == 1

					object.target = nil
					expect(object.target).to(beIdenticalTo(proxy))
					expect(counter) == 0

					sendMessage()
					expect(invocationCount) == 2
				}

				it("should be automatically set as the object's delegate even if it is subsequently isa-swizzled by KVO for observing the delegate key path.") {
					expect(object.target).to(beNil())

					setProxy()
					expect(object.target).to(beIdenticalTo(proxy))

					sendMessage()
					expect(invocationCount) == 1

					var counter = 0
					
					object.reactive
						.signal(forKeyPath: #keyPath(Object.target))
						.observeValues { _ in counter += 1 }
					
					object.target = nil
					expect(object.target).to(beIdenticalTo(proxy))
					expect(counter) == 1

					sendMessage()
					expect(invocationCount) == 2
				}
			}
		}
	}
}
