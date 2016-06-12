import Result
import Quick
import Nimble

#if REACTIVE_SWIFT
	import ReactiveSwift
#else
	import ReactiveCocoa
#endif


class DynamicPropertySpec: QuickSpec {
    override func spec() {
		describe("DynamicProperty") {
			var object: ObservableObject!
			var property: DynamicProperty!
			
			let propertyValue: () -> Int? = {
				if let value: AnyObject = property?.value {
					return value as? Int
				} else {
					return nil
				}
			}
			
			beforeEach {
				object = ObservableObject()
				expect(object.rac_value) == 0
				
				property = DynamicProperty(object: object, keyPath: "rac_value")
			}
			
			afterEach {
				object = nil
			}
			
			it("should read the underlying object") {
				expect(propertyValue()) == 0
				
				object.rac_value = 1
				expect(propertyValue()) == 1
			}
			
			it("should write the underlying object") {
				property.value = 1
				expect(object.rac_value) == 1
				expect(propertyValue()) == 1
			}
			
			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object") {
				var values: [Int] = []
				property.producer.startWithNext { value in
					expect(value).notTo(beNil())
					values.append(value as! Int)
				}
				
				expect(values) == [ 0 ]
				
				property.value = 1
				expect(values) == [ 0, 1 ]
				
				object.rac_value = 2
				expect(values) == [ 0, 1, 2 ]
			}
			
			it("should yield a producer that sends the current value and then the changes for the key path of the underlying object, even if the value actually remains unchanged") {
				var values: [Int] = []
				property.producer.startWithNext { value in
					expect(value).notTo(beNil())
					values.append(value as! Int)
				}
				
				expect(values) == [ 0 ]
				
				property.value = 0
				expect(values) == [ 0, 0 ]
				
				object.rac_value = 0
				expect(values) == [ 0, 0, 0 ]
			}
			
			it("should yield a signal that emits subsequent values for the key path of the underlying object") {
				var values: [Int] = []
				property.signal.observeNext { value in
					expect(value).notTo(beNil())
					values.append(value as! Int)
				}
				
				expect(values) == []
				
				property.value = 1
				expect(values) == [ 1 ]
				
				object.rac_value = 2
				expect(values) == [ 1, 2 ]
			}
			
			it("should yield a signal that emits subsequent values for the key path of the underlying object, even if the value actually remains unchanged") {
				var values: [Int] = []
				property.signal.observeNext { value in
					expect(value).notTo(beNil())
					values.append(value as! Int)
				}
				
				expect(values) == []
				
				property.value = 0
				expect(values) == [ 0 ]
				
				object.rac_value = 0
				expect(values) == [ 0, 0 ]
			}
			
			it("should have a completed producer when the underlying object deallocates") {
				var completed = false
				
				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = DynamicProperty(object: object, keyPath: "rac_value")
					
					property.producer.startWithCompleted {
						completed = true
					}
					
					expect(completed) == false
					expect(property.value).notTo(beNil())
					return property
				}()
				
				expect(completed).toEventually(beTruthy())
				expect(property.value).to(beNil())
			}
			
			it("should have a completed signal when the underlying object deallocates") {
				var completed = false
				
				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = DynamicProperty(object: object, keyPath: "rac_value")
					
					property.signal.observeCompleted {
						completed = true
					}
					
					expect(completed) == false
					expect(property.value).notTo(beNil())
					return property
				}()
				
				expect(completed).toEventually(beTruthy())
				expect(property.value).to(beNil())
			}
			
			it("should retain property while DynamicProperty's underlying object is retained"){
				weak var dynamicProperty: DynamicProperty? = property
				
				property = nil
				expect(dynamicProperty).toNot(beNil())
				
				object = nil
				expect(dynamicProperty).to(beNil())
			}
		}
		
		describe("to a dynamic property") {
			var object: ObservableObject!
			var property: DynamicProperty!
			
			beforeEach {
				object = ObservableObject()
				expect(object.rac_value) == 0
				
				property = DynamicProperty(object: object, keyPath: "rac_value")
			}
			
			afterEach {
				object = nil
			}
			
			it("should bridge values sent on a signal to Objective-C") {
				let (signal, observer) = Signal<Int, NoError>.pipe()
				property <~ signal
				observer.sendNext(1)
				expect(object.rac_value) == 1
			}
			
			it("should bridge values sent on a signal producer to Objective-C") {
				let producer = SignalProducer<Int, NoError>(value: 1)
				property <~ producer
				expect(object.rac_value) == 1
			}
			
			it("should bridge values from a source property to Objective-C") {
				let source = MutableProperty(1)
				property <~ source
				expect(object.rac_value) == 1
			}
		}
    }
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
}
