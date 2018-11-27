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
				expect(view.isHidden) == false

				view.reactive.isHidden <~ hSignal
				hSink.send(value: true)

				expect(view.isHidden) == true
			}

			it("should allow binding of `alphaValue` property") {
				let (avSignal, avSink) = Signal<CGFloat, NoError>.pipe()
				expect(view.alphaValue) == 1.0

				view.reactive.alphaValue <~ avSignal
				avSink.send(value: 0.5)

				expect(view.alphaValue) == 0.5
			}
		}
	}
}
