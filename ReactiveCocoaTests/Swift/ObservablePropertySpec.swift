//
//  ObservablePropertySpec.swift
//  ReactiveCocoa
//
//  Created by Mihail Shulepov on 21/11/14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class ObservablePropertySpec: QuickSpec {
	override func spec() {
		describe("ObservableProperty") {
			it("should immediately send new values") {
				let observableProperty = ObservableProperty(1)
				var value = observableProperty.value
				observableProperty.values.start(next: { newValue in
					value = newValue
				})

				observableProperty.value = 2
				expect(value).to(equal(observableProperty.value))
			}

			it("should send complete when deallocates") {
				var observableProperty: ObservableProperty<Int>? = ObservableProperty(1)
				let signal = observableProperty!.values

				var completed = false
				signal.start(completed: {
					completed = true
				})

				observableProperty = nil
				expect(completed).to(beTruthy())
			}

			it("should send complete if subscribing after it was deallocated") {
				var observableProperty: ObservableProperty<Int>? = ObservableProperty(1)
				let signal = observableProperty!.values
				observableProperty = nil

				var completed = false
				signal.start(completed: {
					completed = true
				})

				expect(completed).to(beTruthy())
			}

			it("should bind to a HotSignal") {
				let property = ObservableProperty(1)
				let (signal, sink) = HotSignal<Int>.pipe()

				property <~ signal
				expect(property.value).to(equal(1))

				sink.put(2)
				expect(property.value).to(equal(2))

				sink.put(3)
				expect(property.value).to(equal(3))
			}

			it("should bind to a ColdSignal") {
				let property = ObservableProperty(-1)
				let scheduler = TestScheduler()

				let signal = ColdSignal<Int> { (sink, disposable) in
					sink.put(.Next(Box(0)))

					var current = 1
					let interval = 1.0
					let schedulerDisposable = scheduler.scheduleAfter(scheduler.currentDate.dateByAddingTimeInterval(interval), repeatingEvery: interval, withLeeway: 0) {
						sink.put(.Next(Box(current++)))

						if current > 2 {
							sink.put(.Completed)
						}
					}

					disposable.addDisposable(schedulerDisposable)
				}

				expect(property.value).to(equal(-1))

				property <~! signal
				expect(property.value).to(equal(0))

				scheduler.advanceByInterval(1.5)
				expect(property.value).to(equal(1))

				scheduler.advanceByInterval(1)
				expect(property.value).to(equal(2))

				scheduler.advanceByInterval(1)
				expect(property.value).to(equal(2))
			}
		}
	}
}
