import ReactiveSwift
import UIKit

extension Reactive where Base: UIScrollView {
	/// Sets the content inset of the scroll view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.contentInset)` instead.")
	public var contentInset: BindingTarget<UIEdgeInsets> {
		return makeBindingTarget { $0.contentInset = $1 }
	}

	/// Sets the scroll indicator insets of the scroll view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.scrollIndicatorInsets)` instead.")
	public var scrollIndicatorInsets: BindingTarget<UIEdgeInsets> {
		return makeBindingTarget { $0.scrollIndicatorInsets = $1 }
	}

	/// Sets whether scrolling the scroll view is enabled.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isScrollEnabled)` instead.")
	public var isScrollEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isScrollEnabled = $1 }
	}

	/// Sets the zoom scale of the scroll view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.zoomScale)` instead.")
	public var zoomScale: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.zoomScale = $1 }
	}

	/// Sets the minimum zoom scale of the scroll view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.minimumZoomScale)` instead.")
	public var minimumZoomScale: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.minimumZoomScale = $1 }
	}

	/// Sets the maximum zoom scale of the scroll view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.maximumZoomScale)` instead.")
	public var maximumZoomScale: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.maximumZoomScale = $1 }
	}
}
