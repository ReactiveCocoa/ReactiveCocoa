import ReactiveSwift
import ReactiveCocoa
import UIKit
import Quick
import Nimble
import enum Result.NoError

private final class UIScrollViewDelegateForZooming: NSObject, UIScrollViewDelegate {
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return scrollView.subviews.first!
	}
}

class UIScrollViewSpec: QuickSpec {
	override func spec() {
		var scrollView: UIScrollView!
		weak var _scrollView: UIScrollView?

		beforeEach {
			scrollView = UIScrollView(frame: .zero)
			_scrollView = scrollView
		}

		afterEach {
			scrollView = nil
			expect(_scrollView).to(beNil())
		}

		it("should accept changes from bindings to its content inset value") {
			scrollView.contentInset = .zero

			let (pipeSignal, observer) = Signal<UIEdgeInsets, NoError>.pipe()
			scrollView.reactive.contentInset <~ SignalProducer(pipeSignal)

			observer.send(value: UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
			expect(scrollView.contentInset) == UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

			observer.send(value: .zero)
			expect(scrollView.contentInset) == UIEdgeInsets.zero
		}

		it("should accept changes from bindings to its scroll indicator insets value") {
			scrollView.scrollIndicatorInsets = .zero

			let (pipeSignal, observer) = Signal<UIEdgeInsets, NoError>.pipe()
			scrollView.reactive.scrollIndicatorInsets <~ SignalProducer(pipeSignal)

			observer.send(value: UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))
			expect(scrollView.scrollIndicatorInsets) == UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

			observer.send(value: .zero)
			expect(scrollView.scrollIndicatorInsets) == UIEdgeInsets.zero
		}

		it("should accept changes from bindings to its scroll enabled state") {
			scrollView.isScrollEnabled = true

			let (pipeSignal, observer) = Signal<Bool, NoError>.pipe()
			scrollView.reactive.isScrollEnabled <~ SignalProducer(pipeSignal)

			observer.send(value: true)
			expect(scrollView.isScrollEnabled) == true

			observer.send(value: false)
			expect(scrollView.isScrollEnabled) == false
		}

		it("should accept changes from bindings to its zoom scale value") {
			let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
			scrollView.addSubview(contentView)
			let delegate = UIScrollViewDelegateForZooming()
			scrollView.delegate = delegate

			scrollView.minimumZoomScale = 1
			scrollView.maximumZoomScale = 5
			scrollView.zoomScale = 1

			let (pipeSignal, observer) = Signal<CGFloat, NoError>.pipe()
			scrollView.reactive.zoomScale <~ SignalProducer(pipeSignal)

			observer.send(value: 3)
			expect(scrollView.zoomScale) == 3
			observer.send(value: 1)
			expect(scrollView.zoomScale) == 1
		}

		it("should accept changes from bindings to its minimum zoom scale value") {
			scrollView.minimumZoomScale = 0

			let (pipeSignal, observer) = Signal<CGFloat, NoError>.pipe()
			scrollView.reactive.minimumZoomScale <~ SignalProducer(pipeSignal)

			observer.send(value: 42)
			expect(scrollView.minimumZoomScale) == 42
			observer.send(value: 0)
			expect(scrollView.minimumZoomScale) == 0
		}

		it("should accept changes from bindings to its maximum zoom scale value") {
			scrollView.maximumZoomScale = 0

			let (pipeSignal, observer) = Signal<CGFloat, NoError>.pipe()
			scrollView.reactive.maximumZoomScale <~ SignalProducer(pipeSignal)

			observer.send(value: 42)
			expect(scrollView.maximumZoomScale) == 42
			observer.send(value: 0)
			expect(scrollView.maximumZoomScale) == 0
		}
	}
}
