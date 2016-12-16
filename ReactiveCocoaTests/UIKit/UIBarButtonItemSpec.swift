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
			barButtonItem.reactive.isEnabled <~ SignalProducer(pipeSignal)

			observer.send(value: false)
			expect(barButtonItem.isEnabled) == false
			
			observer.send(value: true)
			expect(barButtonItem.isEnabled) == true
		}

		it("should accept changes from bindings to its title") {
			let (pipeSignal, observer) = Signal<String?, NoError>.pipe()
			barButtonItem.reactive.title <~ SignalProducer(pipeSignal)

			observer.send(value: "title")
			expect(barButtonItem.title) == "title"

			observer.send(value: nil)
			expect(barButtonItem.title).to(beNil())
		}

		it("should accept changes from bindings to its image") {
			let (pipeSignal, observer) = Signal<UIImage?, NoError>.pipe()
			barButtonItem.reactive.image <~ SignalProducer(pipeSignal)

			let image = UIImage()
			expect(image).notTo(beNil())

			observer.send(value: image)
			expect(barButtonItem.image) == image

			observer.send(value: nil)
			expect(barButtonItem.image).to(beNil())
		}
	}
}
