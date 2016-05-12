import ReactiveCocoa
import Result
import Quick
import Nimble

final class MethodSpec: QuickSpec {
	override func spec() {
		describe("object") {
			it("is weakly referenced") {
				let method: ReactiveCocoa.Method<NSObject, (), String>
				do {
					let object = NSObject()
					method = Method(object: object) { object, _ in object.description }
				}
				expect(method.object).to(beNil())
			}
		}

		describe("binding to signals") {
			describe("with a swift object") {
				var object: TestObject!
				var method: ReactiveCocoa.Method<TestObject, Int, String>!

				beforeEach {
					object = TestObject()
					method = Method(object: object, function: TestObject.string(from:))
				}

				afterEach {
					object = nil
					method = nil
				}

				it("returns a signal with the results of calling the method with each value") {
					let (input, inputObserver) = Signal<Int, NoError>.pipe()
					let output = method.lift(with: input)

					var outputValues: [String] = []
					output.observeNext { outputValues.append($0) }

					inputObserver.sendNext(1)
					inputObserver.sendNext(2)
					inputObserver.sendNext(3)

					expect(outputValues) == ["1", "2", "3"]
				}

				it("is completed on input if the underlying object has been deallocated") {
					let (input, inputObserver) = Signal<Int, NoError>.pipe()
					let output = method.lift(with: input)

					var outputValues: [String] = []
					var completed = false
					output.observeNext { outputValues.append($0) }
					output.observeCompleted { completed = true }

					inputObserver.sendNext(1)
					inputObserver.sendNext(2)
					object = nil
					inputObserver.sendNext(3)

					expect(outputValues) == ["1", "2"]
					expect(completed) == true
				}

				it("is interrupted immediately if the underlying object is already nil") {
					let (input, _) = Signal<Int, NoError>.pipe()
					object = nil

					var interrupted = false
					let output = method.lift(with: input)
					output.observeInterrupted { interrupted = true }

					expect(interrupted) == true
				}
			}

#if _runtime(_ObjC)
			describe("with an Objective-C object") {
				var object: TestObjectiveCObject?
				var method: ReactiveCocoa.Method<TestObjectiveCObject, Int, String>!

				beforeEach {
					object = TestObjectiveCObject()
					method = Method(object: object, function: TestObjectiveCObject.string(from:))
				}

				afterEach {
					object = nil
					method = nil
				}

				it("returns a signal with the results of calling the method with each value") {
					let (input, inputObserver) = Signal<Int, NoError>.pipe()
					let output = method.lift(with: input)

					var outputValues: [String] = []
					output.observeNext { outputValues.append($0) }

					inputObserver.sendNext(1)
					inputObserver.sendNext(2)
					inputObserver.sendNext(3)

					expect(outputValues) == ["1", "2", "3"]
				}

				it("is completed immediately on deallocation if the underlying object is an Objective-C object") {
					let (input, inputObserver) = Signal<Int, NoError>.pipe()
					let output = method.lift(with: input)

					var outputValues: [String] = []
					var completed = false
					output.observeNext { outputValues.append($0) }
					output.observeCompleted { completed = true }

					inputObserver.sendNext(1)
					inputObserver.sendNext(2)
					object = nil

					expect(outputValues) == ["1", "2"]
					expect(completed) == true
				}

				it("is interrupted immediately if the underlying object is already nil") {
					let (input, _) = Signal<Int, NoError>.pipe()
					object = nil

					var interrupted = false
					let output = method.lift(with: input)
					output.observeInterrupted { interrupted = true }

					expect(interrupted) == true
				}
			}
#endif
		}

		describe("binding to producers") {
			describe("with a swift object") {
				var object: TestObject!
				var method: ReactiveCocoa.Method<TestObject, Int, String>!

				beforeEach {
					object = TestObject()
					method = Method(object: object, function: TestObject.string(from:))
				}

				afterEach {
					object = nil
					method = nil
				}

				it("returns an output producer that lazily binds to the input producer") {
					let input = SignalProducer<Int, NoError>(values: [1, 2, 3])

					var sentInput: [Int] = []
					let output = method.lifted(with: input.on(next: { sentInput.append($0) }))
					expect(sentInput) == []

					var sentOutput: [String] = []
					output.startWithNext { sentOutput.append($0) }
					expect(sentInput) == [1, 2, 3]
					expect(sentOutput) == ["1", "2", "3"]
				}

				it("is completed on input if the underlying object is deallocated") {
					let (input, inputObserver) = SignalProducer<Int, NoError>.buffer(1)

					var outputValues: [String] = []
					var completed = false
					method.lifted(with: input).start { event in
						switch event {
						case .Next(let value):
							outputValues.append(value)
						case .Completed:
							completed = true
						default:
							break
						}
					}

					inputObserver.sendNext(1)
					inputObserver.sendNext(2)
					object = nil
					inputObserver.sendNext(3)

					expect(outputValues) == ["1", "2"]
					expect(completed) == true
				}

				it("is completed immediately if the underlying object is already nil") {
					object = nil

					var completed = false
					method.lifted(with: SignalProducer<Int, NoError>.empty).startWithInterrupted { completed = true }

					expect(completed) == true
				}
			}

#if _runtime(_ObjC)
			describe("with an Objective-C object") {
				var object: TestObjectiveCObject?
				var method: ReactiveCocoa.Method<TestObjectiveCObject, Int, String>!

				beforeEach {
					object = TestObjectiveCObject()
					method = Method(object: object, function: TestObjectiveCObject.string(from:))
				}

				afterEach {
					object = nil
					method = nil
				}

				it("returns an output producer that lazily binds to the input producer") {
					let input = SignalProducer<Int, NoError>(values: [1, 2, 3])

					var sentInput: [Int] = []
					let output = method.lifted(with: input.on(next: { sentInput.append($0) }))
					expect(sentInput) == []

					var sentOutput: [String] = []
					output.startWithNext { sentOutput.append($0) }
					expect(sentInput) == [1, 2, 3]
					expect(sentOutput) == ["1", "2", "3"]
				}

				it("is completed immediately if the underlying object is deallocated") {
					let (input, inputObserver) = SignalProducer<Int, NoError>.buffer(1)

					var outputValues: [String] = []
					var completed = false
					method.lifted(with: input).start { event in
						switch event {
						case .Next(let value):
							outputValues.append(value)
						case .Completed:
							completed = true
						default:
							break
						}
					}

					inputObserver.sendNext(1)
					inputObserver.sendNext(2)
					object = nil

					expect(outputValues) == ["1", "2"]
					expect(completed) == true
				}

				it("is completed immediately if the underlying object is already nil") {
					object = nil

					var completed = false
					method.lifted(with: SignalProducer<Int, NoError>.empty).startWithInterrupted { completed = true }

					expect(completed) == true
				}
			}
#endif
		}

		describe("binding") {
			var object: TestObject!
			var method: ReactiveCocoa.Method<TestObject, Int, String>!
			var outputValues: [String]!

			beforeEach {
				object = TestObject()
				outputValues = []
				method = Method(object: object) { object, input in
					let output = object.string(from: input)
					outputValues.append(output)
					return output
				}
			}

			afterEach {
				object = nil
				method = nil
				outputValues = nil
			}

			describe("signals") {
				it("terminates the binding when the return disposable is disposed of") {
					let (input, observer) = Signal<Int, NoError>.pipe()
					let disposable = method <~ input

					observer.sendNext(1)
					disposable.dispose()
					observer.sendNext(2)

					expect(outputValues) == ["1"]
				}

				it("terminates the binding when the object is deallocated") {
					let (input, observer) = Signal<Int, NoError>.pipe()
					method <~ input

					observer.sendNext(1)
					object = nil
					observer.sendNext(2)

					expect(outputValues) == ["1"]
				}
			}

			describe("producers") {
				it("terminates the binding when the return disposable is disposed of") {
					let (input, observer) = SignalProducer<Int, NoError>.buffer(1)
					let disposable = method <~ input

					observer.sendNext(1)
					disposable.dispose()
					observer.sendNext(2)

					expect(outputValues) == ["1"]
				}

				it("terminates the binding when the object is deallocated") {
					let (input, observer) = SignalProducer<Int, NoError>.buffer(1)
					method <~ input

					observer.sendNext(1)
					object = nil
					observer.sendNext(2)

					expect(outputValues) == ["1"]
				}
			}
		}
	}
}

private final class TestObject {
	func string(from number: Int) -> String {
		return String(number)
	}
}

#if _runtime(_ObjC)
private final class TestObjectiveCObject: NSObject {
	func string(from number: Int) -> String {
		return String(number)
	}
}
#endif
