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
					.observeNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
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
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(inner)
				innerObserver.sendNext(4)
				expect(observed) == 4
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
					.startWithNext { value in
						observed = value
					}
				
				outerObserver.sendNext(4)
				innerObserver.sendNext(4)
				expect(observed) == 4
			}
		}
	}
}
