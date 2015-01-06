//
//  SwiftSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import Nimble
import Quick

// Without this, the Swift stdlib won't be linked into the test target (even if
// “Embedded Content Contains Swift Code” is enabled).
class SwiftSpec: QuickSpec {
	override func spec() {
		expect(true).to(beTruthy())
	}
}
