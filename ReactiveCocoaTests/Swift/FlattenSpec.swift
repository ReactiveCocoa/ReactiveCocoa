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
	}
}
