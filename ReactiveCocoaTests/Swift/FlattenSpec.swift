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

class FlattenSpec: QuickSpec {
	override func spec() {

		describe("Signal.switchToLatest") {
			it("disposes inner signals when outer signal interrupted") {

				var disposed = false

				let pipe = Signal<SignalProducer<Void, NoError>, NoError>.pipe()
				let _ = pipe.0.flatten(.Latest)

				pipe.1.sendNext(SignalProducer<Void, NoError> { _, disposable in
					disposable += ActionDisposable {
						disposed = true
					}
				})

				pipe.1.sendInterrupted()
				expect(disposed).to(beTrue())
			}
		}

		describe("SignalProducer.switchToLatest") {
			it("disposes original signal when result signal interrupted") {
				
				var disposed = false

				let disposable = SignalProducer<SignalProducer<Void, NoError>, NoError> { observer, disposable in
					disposable += ActionDisposable {
						disposed = true
					}
				}.flatten(.Latest).start()

				disposable.dispose()
				expect(disposed).to(beTrue())
			}
		}
	}
}
