//
//  ObjectiveCBridgingSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class ObjectiveCBridgingSpec: QuickSpec {
	override func spec() {
		describe("RACSignal.asSignalProducer") {
			pending("should subscribe once per start()") {
			}

			pending("should automatically replace nil NSErrors") {
			}
		}

		describe("asRACSignal") {
			describe("on a Signal") {
				pending("should forward events") {
				}

				pending("should convert errors to NSError") {
				}
			}

			describe("on a SignalProducer") {
				pending("should start once per subscription") {
				}

				pending("should convert errors to NSError") {
				}
			}
		}

		describe("RACCommand.asAction") {
			pending("should reflect the enabledness of the command") {
			}

			pending("should not execute the command upon apply()") {
			}

			pending("should execute the command once per start()") {
			}
		}

		describe("asRACCommand") {
			pending("should reflect the enabledness of the action") {
			}

			pending("should apply and start a signal once per execution") {
			}
		}
	}
}
