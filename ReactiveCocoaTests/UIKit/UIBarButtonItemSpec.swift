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

		it("should accept changes from bindings to its style") {
			let (pipeSignal, observer) = Signal<UIBarButtonItem.Style, NoError>.pipe()
			barButtonItem.reactive.style <~ SignalProducer(pipeSignal)

			observer.send(value: .done)
			expect(barButtonItem.style) == .done

			observer.send(value: .plain)
			expect(barButtonItem.style) == .plain
		}

		it("should accept changes from bindings to its width") {
			let (pipeSignal, observer) = Signal<CGFloat, NoError>.pipe()
			barButtonItem.reactive.width <~ SignalProducer(pipeSignal)

			observer.send(value: 42.0)
			expect(barButtonItem.width) == 42.0

			observer.send(value: 320.0)
			expect(barButtonItem.width) == 320.0

			observer.send(value: 0.0)
			expect(barButtonItem.width) == 0.0
		}

		it("should accept changes from bindings to its possible titles") {
			let (pipeSignal, observer) = Signal<Set<String>?, NoError>.pipe()
			barButtonItem.reactive.possibleTitles <~ SignalProducer(pipeSignal)

			let possibleTitles = Set(["Unread (123,456,789)", "Unread"])
			observer.send(value: possibleTitles)
			expect(barButtonItem.possibleTitles) == possibleTitles

			observer.send(value: nil)
			expect(barButtonItem.possibleTitles).to(beNil())
		}

		it("should accept changes from bindings to its custom view") {
			let firstChange = UIView()
			firstChange.accessibilityIdentifier = "first"

			let secondChange = UIView()
			secondChange.accessibilityIdentifier = "second"

			barButtonItem.customView = nil

			let (pipeSignal, observer) = Signal<UIView?, NoError>.pipe()
			barButtonItem.reactive.customView <~ pipeSignal

			observer.send(value: firstChange)
			expect(barButtonItem.customView) == firstChange

			observer.send(value: secondChange)
			expect(barButtonItem.customView) == secondChange

			observer.send(value: nil)
			expect(barButtonItem.customView).to(beNil())
		}
	}
}
