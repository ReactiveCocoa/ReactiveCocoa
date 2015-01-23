//
//  PropertySpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import LlamaKit
import Nimble
import Quick
import ReactiveCocoa

class PropertySpec: QuickSpec {
	override func spec() {
		describe("ConstantProperty") {
			pending("should have the value given at initialization") {
			}

			pending("should yield a producer that sends the current value then completes") {
			}
		}

		describe("MutableProperty") {
			pending("should have the value given at initialization") {
			}

			pending("should yield a producer that sends the current value then all changes") {
			}

			pending("should complete its producer when deallocated") {
			}
		}

		describe("PropertyOf") {
			pending("should pass through behaviors of the input property") {
			}
		}

		describe("binding") {
			describe("from a Signal") {
				pending("should update the property with values sent from the signal") {
				}

				pending("should tear down the binding when disposed") {
				}

				pending("should tear down the binding when the property deallocates") {
				}
			}

			describe("from a SignalProducer") {
				pending("should start a signal and update the property with its values") {
				}

				pending("should tear down the binding when disposed") {
				}

				pending("should tear down the binding when the property deallocates") {
				}
			}

			describe("from another property") {
				pending("should take the source property's current value") {
				}

				pending("should update with changes to the source property's value") {
				}

				pending("should tear down the binding when disposed") {
				}

				pending("should tear down the binding when the source property deallocates") {
				}

				pending("should tear down the binding when the destination property deallocates") {
				}
			}
		}
	}
}
