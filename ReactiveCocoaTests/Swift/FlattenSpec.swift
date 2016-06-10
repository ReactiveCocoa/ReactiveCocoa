//
//  FlattenSpec.swift
//  ReactiveCocoa
//
//  Created by Oleg Shnitko on 1/22/16.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa

private extension SignalType {
	typealias Pipe = (signal: Signal<Value, Error>, observer: Observer<Value, Error>)
}

private typealias Pipe = Signal<SignalProducer<Int, TestError>, TestError>.Pipe

class FlattenSpec: QuickSpec {
	override func spec() {
		func describeSignalFlattenDisposal(flattenStrategy: FlattenStrategy, name: String) {
			describe(name) {
				var pipe: Pipe!
				var disposable: Disposable?

				beforeEach {
					pipe = Signal.pipe()
					disposable = pipe.signal
						.flatten(flattenStrategy)
						.observe { _ in }
				}

				afterEach {
					disposable?.dispose()
				}

				context("disposal") {
					var disposed = false

					beforeEach {
						disposed = false
						pipe.observer.sendNext(SignalProducer<Int, TestError> { _, disposable in
							disposable += ActionDisposable {
								disposed = true
							}
						})
					}

					it("should dispose inner signals when outer signal interrupted") {
						pipe.observer.sendInterrupted()
						expect(disposed) == true
					}

					it("should dispose inner signals when outer signal failed") {
						pipe.observer.sendFailed(.Default)
						expect(disposed) == true
					}

					it("should not dispose inner signals when outer signal completed") {
						pipe.observer.sendCompleted()
						expect(disposed) == false
					}
				}
			}
		}

		context("Signal") {
			describeSignalFlattenDisposal(.Latest, name: "switchToLatest")
			describeSignalFlattenDisposal(.Merge, name: "merge")
			describeSignalFlattenDisposal(.Concat, name: "concat")
		}

		func describeSignalProducerFlattenDisposal(flattenStrategy: FlattenStrategy, name: String) {
			describe(name) {
				it("disposes original signal when result signal interrupted") {
					var disposed = false

					let disposable = SignalProducer<SignalProducer<(), NoError>, NoError> { _, disposable in
						disposable += ActionDisposable {
							disposed = true
						}
					}
						.flatten(flattenStrategy)
						.start()

					disposable.dispose()
					expect(disposed) == true
				}
			}
		}

		context("SignalProducer") {
			describeSignalProducerFlattenDisposal(.Latest, name: "switchToLatest")
			describeSignalProducerFlattenDisposal(.Merge, name: "merge")
			describeSignalProducerFlattenDisposal(.Concat, name: "concat")
		}
		
		describe("Signal.flatten()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = Signal<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = Signal<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = Signal<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = Signal<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with SequenceType as a value") {
				let (signal, innerObserver) = Signal<[Int], NoError>.pipe()
				let sequence = [1, 2, 3]
				var observedValues = [Int]()
				
				signal
					.flatten(.Concat)
					.observeNext { value in
						observedValues.append(value)
					}
				
				innerObserver.sendNext(sequence)
				expect(observedValues) == sequence
			}
		}
		
		describe("SignalProducer.flatten()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = SignalProducer<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = SignalProducer<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = SignalProducer<Inner, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = SignalProducer<Inner, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatten(.Latest)
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with SequenceType as a value") {
				let sequence = [1, 2, 3]
				var observedValues = [Int]()
				
				let producer = SignalProducer<[Int], NoError>(value: sequence)
				producer
					.flatten(.Latest)
					.startWithNext { value in
						observedValues.append(value)
					}
				
				expect(observedValues) == sequence
			}
		}
		
		describe("Signal.flatMap()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = Signal<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = Signal<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = Signal<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = Signal<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
		}
		
		describe("SignalProducer.flatMap()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = SignalProducer<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError Signal") {
				typealias Inner = Signal<Int, NoError>
				typealias Outer = SignalProducer<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with NoError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = SignalProducer<Int, NoError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
			
			it("works with TestError and a NoError SignalProducer") {
				typealias Inner = SignalProducer<Int, NoError>
				typealias Outer = SignalProducer<Int, TestError>
				
				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()
				
				var observed: Int? = nil
				outer
					.flatMap(.Latest) { _ in inner }
					.assumeNoErrors()
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
		}
		
		describe("Signal.merge()") {
			it("should emit values from all signals") {
				let (signal1, observer1) = Signal<Int, NoError>.pipe()
				let (signal2, observer2) = Signal<Int, NoError>.pipe()
				
				let mergedSignals = Signal.merge([signal1, signal2])
				
				var lastValue: Int?
				mergedSignals.observeNext { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.sendNext(1)
				expect(lastValue) == 1
				
				observer2.sendNext(2)
				expect(lastValue) == 2
				
				observer1.sendNext(3)
				expect(lastValue) == 3
			}
			
			it("should not stop when one signal completes") {
				let (signal1, observer1) = Signal<Int, NoError>.pipe()
				let (signal2, observer2) = Signal<Int, NoError>.pipe()
				
				let mergedSignals = Signal.merge([signal1, signal2])
				
				var lastValue: Int?
				mergedSignals.observeNext { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.sendNext(1)
				expect(lastValue) == 1
				
				observer1.sendCompleted()
				expect(lastValue) == 1
				
				observer2.sendNext(2)
				expect(lastValue) == 2
			}
			
			it("should complete when all signals complete") {
				let (signal1, observer1) = Signal<Int, NoError>.pipe()
				let (signal2, observer2) = Signal<Int, NoError>.pipe()
				
				let mergedSignals = Signal.merge([signal1, signal2])
				
				var completed = false
				mergedSignals.observeCompleted { completed = true }
				
				expect(completed) == false
				
				observer1.sendNext(1)
				expect(completed) == false
				
				observer1.sendCompleted()
				expect(completed) == false
				
				observer2.sendCompleted()
				expect(completed) == true
			}
		}
		
		describe("SignalProducer.merge()") {
			it("should emit values from all producers") {
				let (signal1, observer1) = SignalProducer<Int, NoError>.pipe()
				let (signal2, observer2) = SignalProducer<Int, NoError>.pipe()
				
				let mergedSignals = SignalProducer.merge([signal1, signal2])
				
				var lastValue: Int?
				mergedSignals.startWithNext { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.sendNext(1)
				expect(lastValue) == 1
				
				observer2.sendNext(2)
				expect(lastValue) == 2
				
				observer1.sendNext(3)
				expect(lastValue) == 3
			}
			
			it("should not stop when one producer completes") {
				let (signal1, observer1) = SignalProducer<Int, NoError>.pipe()
				let (signal2, observer2) = SignalProducer<Int, NoError>.pipe()
				
				let mergedSignals = SignalProducer.merge([signal1, signal2])
				
				var lastValue: Int?
				mergedSignals.startWithNext { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.sendNext(1)
				expect(lastValue) == 1
				
				observer1.sendCompleted()
				expect(lastValue) == 1
				
				observer2.sendNext(2)
				expect(lastValue) == 2
			}
			
			it("should complete when all producers complete") {
				let (signal1, observer1) = SignalProducer<Int, NoError>.pipe()
				let (signal2, observer2) = SignalProducer<Int, NoError>.pipe()
				
				let mergedSignals = SignalProducer.merge([signal1, signal2])
				
				var completed = false
				mergedSignals.startWithCompleted { completed = true }
				
				expect(completed) == false
				
				observer1.sendNext(1)
				expect(completed) == false
				
				observer1.sendCompleted()
				expect(completed) == false
				
				observer2.sendCompleted()
				expect(completed) == true
			}
		}

		describe("SignalProducer.prefix()") {
			it("should emit initial value") {
				let (signal, observer) = SignalProducer<Int, NoError>.pipe()

				let mergedSignals = signal.prefix(value: 0)

				var lastValue: Int?
				mergedSignals.startWithNext { lastValue = $0 }

				expect(lastValue) == 0

				observer.sendNext(1)
				expect(lastValue) == 1

				observer.sendNext(2)
				expect(lastValue) == 2

				observer.sendNext(3)
				expect(lastValue) == 3
			}

			it("should emit initial value") {
				let (signal, observer) = SignalProducer<Int, NoError>.pipe()
				
				let mergedSignals = signal.prefix(SignalProducer(value: 0))
				
				var lastValue: Int?
				mergedSignals.startWithNext { lastValue = $0 }
				
				expect(lastValue) == 0
				
				observer.sendNext(1)
				expect(lastValue) == 1
				
				observer.sendNext(2)
				expect(lastValue) == 2
				
				observer.sendNext(3)
				expect(lastValue) == 3
			}
		}
		
		describe("SignalProducer.concat(value:)") {
			it("should emit final value") {
				let (signal, observer) = SignalProducer<Int, NoError>.pipe()
				
				let mergedSignals = signal.concat(value: 4)
				
				var lastValue: Int?
				mergedSignals.startWithNext { lastValue = $0 }
								
				observer.sendNext(1)
				expect(lastValue) == 1
				
				observer.sendNext(2)
				expect(lastValue) == 2
				
				observer.sendNext(3)
				expect(lastValue) == 3
				
				observer.sendCompleted()
				expect(lastValue) == 4
			}
		}
	}
}
