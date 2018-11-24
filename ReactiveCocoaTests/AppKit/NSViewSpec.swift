import Quick
import Nimble
import Result
import ReactiveSwift
import ReactiveCocoa
import AppKit

class NSViewSpec: QuickSpec {
	override func spec() {
		describe("NSView") {
			var view: NSView!

			beforeEach {
				view = NSView()
			}

			it("should allow binding of `isHidden` property") {
				let (hSignal, hSink) = Signal<Bool, NoError>.pipe()
				expect(view.isHidden).to(beFalse())

				view.reactive.isHidden <~ hSignal
				hSink.send(value: true)

				expect(view.isHidden).to(beTrue())
			}
		}
	}
}
