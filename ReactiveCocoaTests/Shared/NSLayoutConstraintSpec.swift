#if canImport(AppKit) || canImport(UIKit)

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import ReactiveSwift
import ReactiveCocoa
import Quick
import Nimble

class NSLayoutConstraintSpec: QuickSpec {
    override func spec() {
		var constraint: NSLayoutConstraint!
		weak var _constraint: NSLayoutConstraint?

		beforeEach {
			constraint = NSLayoutConstraint()
			_constraint = constraint
		}

		afterEach {
			constraint = nil
			expect(_constraint).to(beNil())
		}

		it("should accept changes from bindings to its constant") {
			expect(constraint.constant).to(equal(0.0))

			let (pipeSignal, observer) = Signal<CGFloat, Never>.pipe()

			constraint.reactive.constant <~ pipeSignal

			observer.send(value: 5.0)
			expect(constraint.constant) ≈ 5.0

			observer.send(value: -3.0)
			expect(constraint.constant) ≈ -3.0
		}
    }
}
#endif
