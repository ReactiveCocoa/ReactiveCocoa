import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

class UIImageViewSpec: QuickSpec {
	override func spec() {
		var imageView: UIImageView!
		weak var _imageView: UIImageView?

		beforeEach {
			imageView = UIImageView(frame: .zero)
			_imageView = imageView
		}

		afterEach {
			imageView = nil
			expect(_imageView).to(beNil())
		}

		it("should accept changes from bindings to its displaying image") {
			let firstChange = UIImage()
			let secondChange = UIImage()

			let (pipeSignal, observer) = Signal<UIImage?, NoError>.pipe()
			imageView.reactive.image <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(imageView.image) == firstChange

			observer.send(value: secondChange)
			expect(imageView.image) == secondChange
		}

		it("should accept changes from bindings to its displaying image when highlighted") {
			let firstChange = UIImage()
			let secondChange = UIImage()

			let (pipeSignal, observer) = Signal<UIImage?, NoError>.pipe()
			imageView.reactive.highlightedImage <~ SignalProducer(pipeSignal)

			observer.send(value: firstChange)
			expect(imageView.highlightedImage) == firstChange

			observer.send(value: secondChange)
			expect(imageView.highlightedImage) == secondChange
		}
	}
}
