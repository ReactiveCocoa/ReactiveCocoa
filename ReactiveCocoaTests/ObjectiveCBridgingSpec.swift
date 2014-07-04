//
//  ObjectiveCBridgingSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import Nimble
import Quick
import ReactiveCocoa

class ObjectiveCBridgingSpec: QuickSpec {
	override func spec() {
		describe("RACSignal") {
			let signal = RACSignal.createSignal { subscriber in
				subscriber.sendNext("foobar")
				subscriber.sendCompleted()
				return nil
			}

			it("should convert to a Signal") {
				expect(signal.asSignalOfLatestValue().current as NSObject?).to.equal("foobar")
			}
		}
	}
}
