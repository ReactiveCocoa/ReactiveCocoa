//
//  PropertySpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

private let initialPropertyValue = "InitialValue"
private let subsequentPropertyValue = "SubsequentValue"

class PropertySpec: QuickSpec {
	override func spec() {
		describe("ConstantProperty") {
			it("should have the value given at initialization") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				expect(constantProperty.value).to(equal(initialPropertyValue))
			}

			it("should yield a producer that sends the current value then completes") {
				let constantProperty = ConstantProperty(initialPropertyValue)

				var sentValue: String?
				var signalCompleted = false

				constantProperty.producer.start(next: { value in
					sentValue = value
				}, completed: {
					signalCompleted = true
				})

				expect(sentValue).to(equal(initialPropertyValue))
				expect(signalCompleted).to(beTruthy())
			}
		}

		describe("MutableProperty") {
			it("should have the value given at initialization") {
				let mutableProperty = MutableProperty(initialPropertyValue)

				expect(mutableProperty.value).to(equal(initialPropertyValue))
			}

			it("should yield a producer that sends the current value then all changes") {
				let mutableProperty = MutableProperty(initialPropertyValue)

				var sentValue: String?

				mutableProperty.producer.start(next: { value in
					sentValue = value
				})

				expect(sentValue).to(equal(initialPropertyValue))
				mutableProperty.value = subsequentPropertyValue
				expect(sentValue).to(equal(subsequentPropertyValue))
			}

			it("should complete its producer when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)

				var signalCompleted = false

				mutableProperty?.producer.start(completed: {
					signalCompleted = true
				})

				mutableProperty = nil
				expect(signalCompleted).to(beTruthy())
			}

			it("should not deadlock on recursive value access") {
				let (producer, sink) = SignalProducer<Int, NoError>.buffer()
				let property = MutableProperty(0)
				var value: Int?

				property <~ producer
				property.producer.start(next: { _ in
					value = property.value
				})

				sendNext(sink, 10)
				expect(value).to(equal(10))
			}

			it("should not deadlock on recursive observation") {
				let property = MutableProperty(0)

				var value: Int?
				property.producer.start(next: { _ in
					property.producer.start(next: { x in value = x })
				})

				expect(value).to(equal(0))

				property.value = 1
				expect(value).to(equal(1))
			}
		}

		describe("PropertyOf") {
			describe("from a PropertyType") {
				it("should pass through behaviors of the input property") {
					let constantProperty = ConstantProperty(initialPropertyValue)
					let propertyOf = PropertyOf(constantProperty)

					var sentValue: String?
					var producerCompleted = false

					propertyOf.producer.start(next: { value in
						sentValue = value
					}, completed: {
						producerCompleted = true
					})

					expect(sentValue).to(equal(initialPropertyValue))
					expect(producerCompleted).to(beTruthy())
				}
			}
			
			describe("from a value and SignalProducer") {
				it("should initially take on the supplied value") {
					let property = PropertyOf(
						initialValue: initialPropertyValue,
						producer: SignalProducer.never)
					
					expect(property.value).to(equal(initialPropertyValue))
				}
				
				it("should take on each value sent on the producer") {
					let property = PropertyOf(
						initialValue: initialPropertyValue,
						producer: SignalProducer(value: subsequentPropertyValue))
					
					expect(property.value).to(equal(subsequentPropertyValue))
				}
			}
			
			describe("from a value and Signal") {
				it("should initially take on the supplied value, then values sent on the signal") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let property = PropertyOf(
						initialValue: initialPropertyValue,
						signal: signal)
					
					expect(property.value).to(equal(initialPropertyValue))
					
					sendNext(observer, subsequentPropertyValue)
					
					expect(property.value).to(equal(subsequentPropertyValue))
				}
			}
		}

		describe("MutableCollectionProperty") {
			describe("initialization") {

	            it("should properly update the value once initialized") {
	                let array: [String] = ["test1, test2"]
	                let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                expect(property.value) == array
	            }
	        }

	        describe("updates") {

	            context("full update") {

	                it("should notify the main producer") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: { event in
	                            switch event {
	                            case .Next(_):
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.value = ["test2", "test3"]
	                    })
	                }

	                it("should notify the changes producer with the replaced enum type") {
	                    let array: [String] = ["test1", "test2"]
	                    let newArray: [String] = ["test2", "test3"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: {
	                        (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Replacement(let newValue):
	                                    expect(newValue) == newArray
	                                    expect(i) == 1
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                                i++
	                            default: break
	                            }
	                        }).start()
	                        property.value = newArray
	                    })
	                }
	            }

	        }

	        describe("deletion") {

	            context("delete at a given index") {

	                it("should notify the main producer") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: {
	                        (done) -> Void in
	                        property.producer.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let newValue):
	                                expect(newValue) == ["test1"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.removeAtIndex(1)
	                    })
	                }

	                it("should notify the changes producer with the right type") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: {
	                        (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Deletion(let index, let element):
	                                    expect(i) == 1
	                                    expect(index) == 1
	                                    expect(element) == "test2"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.removeAtIndex(1)
	                    })
	                }
	            }
	            
	            context("deleting the last element", {
	                
	                it("should notify the deletion to the main producer") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                expect(change) == ["test1"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.removeLast()
	                    })
	                }
	                
	                it("should notify the deletion to the changes producer with the right type") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Deletion(let index, let element):
	                                    expect(i) == 1
	                                    expect(index) == 1
	                                    expect(element) == "test2"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.removeLast()
	                    })
	                }
	                
	            })
	            
	            context("deleting the first element", {
	                it("should notify the deletion to the main producer") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                expect(change) == ["test2"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.removeFirst()
	                    })
	                }
	                
	                it("should notify the deletion to the changes producer with the right type") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Deletion(let index, let element):
	                                    expect(i) == 1
	                                    expect(index) == 0
	                                    expect(element) == "test1"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.removeFirst()
	                    })
	                }
	            })
	            
	            context("remove all elements", {
	                it("should notify the deletion to the main producer") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                expect(change) == []
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.removeAll()
	                    })
	                }
	                
	                it("should notify the deletion to the changes producer with the right type") {
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Deletion(let index, let element):
	                                    expect(i) >= 1
	                                    expect(index) == array.count - i
	                                    expect(element) == "test\(array.count - (i-1))"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.removeAll()
	                    })
	                }
	            })

	        }
	        
	        context("adding elements") { () -> Void in
	            
	            context("appending elements individually", { () -> Void in
	                
	                it("should notify about the change to the main producer", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: { (event) in
	                            switch event {
	                            case .Next(let next):
	                                expect(next) == ["test1", "test2", "test3"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.append("test3")
	                    })
	                })
	                
	                it("should notify the changes producer about the adition", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Addition(let index, let element):
	                                    expect(i) == 1
	                                    expect(index) == 2
	                                    expect(element) == "test3"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.append("test3")
	                    })
	                })
	                
	            })
	            
	            context("appending elements from another array", { () -> Void in
	                
	                it("should notify about the change to the main producer", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: { (event) in
	                            switch event {
	                            case .Next(let next):
	                                expect(next) == ["test1", "test2", "test3", "test4"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.appendContentsOf(["test3", "test4"])
	                    })
	                })
	                
	                it("should notify the changes producer about the adition", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Addition(let index, let element):
	                                    expect(i) >= 1
	                                    expect(index) == i+1
	                                    expect(element) == "test\(i+2)"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.appendContentsOf(["test3", "test4"])
	                    })
	                })
	                
	            })
	            
	            context("inserting elements", { () -> Void in
	                
	                it("should notify about the change to the main producer", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: { (event) in
	                            switch event {
	                            case .Next(let next):
	                                expect(next) == ["test0", "test1", "test2"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.insert("test0", atIndex: 0)
	                    })
	                })
	                
	                it("should notify the changes producer about the adition", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Insertion(let index, let element):
	                                    expect(i) == 1
	                                    expect(index) == 0
	                                    expect(element) == "test0"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.insert("test0", atIndex: 0)
	                    })
	                })
	                
	            })
	            
	            context("replacing elements", { () -> Void in
	                
	                it("should notify about the change to the main producer", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        property.producer.on(event: { (event) in
	                            switch event {
	                            case .Next(let next):
	                                expect(next) == ["test3", "test4"]
	                                done()
	                            default: break
	                            }
	                        }).start()
	                        property.replace(Range<Int>(start: 0, end: 1), with: ["test3", "test4"])
	                    })
	                })
	                
	                it("should notify the changes producer about the adition", closure: { () -> () in
	                    let array: [String] = ["test1", "test2"]
	                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
	                    waitUntil(action: { (done) -> Void in
	                        var i: Int = 0
	                        property.changes.on(event: {
	                            event in
	                            switch event {
	                            case .Next(let change):
	                                switch change {
	                                case .StartChange:
	                                    expect(i) == 0
	                                case .Replaced(let index, let element):
	                                    expect(i) >= 1
	                                    expect(index) == i - 1
	                                    expect(element) == "test\(index+3)"
	                                case .EndChange:
	                                    done()
	                                default: break
	                                }
	                            default: break
	                            }
	                            i++
	                        }).start()
	                        property.replace(Range<Int>(start: 0, end: 1), with: ["test3", "test4"])
	                    })
	                })
	                
	            })
	            
	        }
		}

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
				expect(object.rac_value).to(equal(0))

				property = DynamicProperty(object: object, keyPath: "rac_value")
			}

			afterEach {
				object = nil
			}

			it("should read the underlying object") {
				expect(propertyValue()).to(equal(0))

				object.rac_value = 1
				expect(propertyValue()).to(equal(1))
			}

			it("should write the underlying object") {
				property.value = 1
				expect(object.rac_value).to(equal(1))
				expect(propertyValue()).to(equal(1))
			}

			it("should observe changes to the property and underlying object") {
				var values: [Int] = []
				property.producer.start(next: { value in
					expect(value).notTo(beNil())
					values.append((value as? Int) ?? -1)
				})

				expect(values).to(equal([ 0 ]))

				property.value = 1
				expect(values).to(equal([ 0, 1 ]))

				object.rac_value = 2
				expect(values).to(equal([ 0, 1, 2 ]))
			}

			it("should complete when the underlying object deallocates") {
				var completed = false

				property = {
					// Use a closure so this object has a shorter lifetime.
					let object = ObservableObject()
					let property = DynamicProperty(object: object, keyPath: "rac_value")

					property.producer.start(completed: {
						completed = true
					})

					expect(completed).to(beFalsy())
					expect(property.value).notTo(beNil())
					return property
				}()

				expect(completed).toEventually(beTruthy())
				expect(property.value).to(beNil())
			}
			
			it("should retain property while DynamicProperty's object is retained"){
				weak var dynamicProperty: DynamicProperty? = property
				
				property = nil
				expect(dynamicProperty).toNot(beNil())
				
				object = nil
				expect(dynamicProperty).to(beNil())
			}
		}

		describe("binding") {
			describe("from a Signal") {
				it("should update the property with values sent from the signal") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signal

					// Verify that the binding hasn't changed the property value:
					expect(mutableProperty.value).to(equal(initialPropertyValue))

					sendNext(observer, subsequentPropertyValue)
					expect(mutableProperty.value).to(equal(subsequentPropertyValue))
				}

				it("should tear down the binding when disposed") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty <~ signal
					bindingDisposable.dispose()

					sendNext(observer, subsequentPropertyValue)
					expect(mutableProperty.value).to(equal(initialPropertyValue))
				}
				
				it("should tear down the binding when bound signal is completed") {
					let (signal, observer) = Signal<String, NoError>.pipe()
					
					let mutableProperty = MutableProperty(initialPropertyValue)
					
					let bindingDisposable = mutableProperty <~ signal
					
					expect(bindingDisposable.disposed).to(beFalsy())
					sendCompleted(observer)
					expect(bindingDisposable.disposed).to(beTruthy())
				}
				
				it("should tear down the binding when the property deallocates") {
					let (signal, observer) = Signal<String, NoError>.pipe()

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty! <~ signal

					mutableProperty = nil
					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}

			describe("from a SignalProducer") {
				it("should start a signal and update the property with its values") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signalProducer

					expect(mutableProperty.value).to(equal(signalValues.last!))
				}

				it("should tear down the binding when disposed") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)
					let disposable = mutableProperty <~ signalProducer

					disposable.dispose()
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when bound signal is completed") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let (signalProducer, observer) = SignalProducer<String, NoError>.buffer(1)
					
					let mutableProperty = MutableProperty(initialPropertyValue)
					mutableProperty <~ signalProducer

					sendCompleted(observer)
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the property deallocates") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, NoError>(values: signalValues)

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)
					let disposable = mutableProperty! <~ signalProducer

					mutableProperty = nil
					expect(disposable.disposed).to(beTruthy())
				}
			}

			describe("from another property") {
				it("should take the source property's current value") {
					let sourceProperty = ConstantProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					expect(destinationProperty.value).to(equal(initialPropertyValue))
				}

				it("should update with changes to the source property's value") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					sourceProperty.value = subsequentPropertyValue
					expect(destinationProperty.value).to(equal(subsequentPropertyValue))
				}

				it("should tear down the binding when disposed") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					let bindingDisposable = destinationProperty <~ sourceProperty.producer
					bindingDisposable.dispose()

					sourceProperty.value = subsequentPropertyValue

					expect(destinationProperty.value).to(equal(initialPropertyValue))
				}

				it("should tear down the binding when the source property deallocates") {
					var sourceProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")
					destinationProperty <~ sourceProperty!.producer

					sourceProperty = nil
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the destination property deallocates") {
					let sourceProperty = MutableProperty(initialPropertyValue)
					var destinationProperty: MutableProperty<String>? = MutableProperty("")

					let bindingDisposable = destinationProperty! <~ sourceProperty.producer
					destinationProperty = nil

					expect(bindingDisposable.disposed).to(beTruthy())
				}
			}
		}
	}
}

private class ObservableObject: NSObject {
	dynamic var rac_value: Int = 0
}
