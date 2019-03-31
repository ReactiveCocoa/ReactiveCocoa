import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import AppKit
import enum Result.NoError

class NSImageViewSpec: QuickSpec {
	override func spec() {
		var imageView: NSImageView!
		weak var _imageView: NSImageView?

		beforeEach {
			imageView = NSImageView(frame: .zero)
			_imageView = imageView
		}

		afterEach {
			imageView = nil
			expect(_imageView).to(beNil())
		}

		it("should accept changes from bindings to its enabling state") {
			imageView.isEnabled = false

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			imageView.reactive.isEnabled <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(imageView.isEnabled) == true

			observer.send(value: false)
			expect(imageView.isEnabled) == false
		}

		it("should accept changes from bindings to its image") {

			let (pipeSignal, observer) = Signal<NSImage?, NoError>.pipe()
			imageView.reactive.image <~ SignalProducer(pipeSignal)

			let theImage = NSImage(named: NSImage.userName)

			observer.send(value: theImage)
			expect(imageView.image) == theImage

			observer.send(value: nil)
			expect(imageView.image).to(beNil())
		}
	}
}

