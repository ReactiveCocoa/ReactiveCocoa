import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import UIKit
import enum Result.NoError

class UIBarButtonItemSpec: QuickSpec {
	override func spec() {
		var barButtonItem: UIBarButtonItem!
		weak var _barButtonItem: UIBarButtonItem?

		beforeEach {
			barButtonItem = UIBarButtonItem()
			_barButtonItem = barButtonItem
		}

		afterEach {
			barButtonItem = nil
			expect(_barButtonItem).to(beNil())
		}

		it("should not be retained with the presence of a `pressed` action") {
			let action = Action<(),(),NoError> { SignalProducer(value: ()) }
			barButtonItem.reactive.pressed = CocoaAction(action)
		}

		it("should accept changes from bindings to its enabling state") {
			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			barButtonItem.reactive.isEnabled <~ SignalProducer(signal: pipeSignal)

			observer.send(value: false)
			expect(barButtonItem.isEnabled) == false
			
			observer.send(value: true)
			expect(barButtonItem.isEnabled) == true
		}
	}
}
