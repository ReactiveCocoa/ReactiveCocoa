//
//  ObservablePropertySpec.swift
//  ReactiveCocoa
//
//  Created by Mihail Shulepov on 21/11/14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import Nimble
import Quick
import ReactiveCocoa


class ObservablePropertySpec: QuickSpec {
	override func spec() {
		describe("ObservableProperty") {
			it("should immediately send new values") {
				let observableProperty = ObservableProperty(1)
				var value = observableProperty.value
				observableProperty.values().start { newValue in
					value = newValue
				}
				observableProperty.value = 2
				expect(value).to(equal(observableProperty.value))
			}
			
			it("should send complete when deallocates") {
				var observableProperty: ObservableProperty<Int>? = ObservableProperty(1)
				let signal = observableProperty!.values()
				
				var completed = false
				signal.start(completed: {
					completed = true
				})
				
				observableProperty = nil
				expect(completed).to(beTruthy())
			}
			
			it("should send complete if subscribing after it was deallocated") {
				var observableProperty: ObservableProperty<Int>? = ObservableProperty(1)
				let signal = observableProperty!.values()
				observableProperty = nil
				
				var completed = false
				signal.start(completed: {
					completed = true
				})
				
				expect(completed).to(beTruthy())
			}
		}
	}
}
