import ReactiveSwift
import UIKit

extension Reactive where Base: UIScrollView {
	/// Sets the content inset of the scroll view.
	public var contentInset: BindingTarget<UIEdgeInsets> {
		return makeBindingTarget { $0.contentInset = $1 }
	}

	/// Sets the scroll indicator insets of the scroll view.
	public var scrollIndicatorInsets: BindingTarget<UIEdgeInsets> {
		return makeBindingTarget { $0.scrollIndicatorInsets = $1 }
	}

	/// Sets whether scrolling the scroll view is enabled.
	public var isScrollEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isScrollEnabled = $1 }
	}

	/// Sets the zoom scale of the scroll view.
	public var zoomScale: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.zoomScale = $1 }
	}

	/// Sets the minimum zoom scale of the scroll view.
	public var minimumZoomScale: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.minimumZoomScale = $1 }
	}

	/// Sets the maximum zoom scale of the scroll view.
	public var maximumZoomScale: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.maximumZoomScale = $1 }
	}
	
	#if os(iOS)
	/// Sets whether the scroll view scrolls to the top when the menu is tapped.
	public var scrollsToTop: BindingTarget<Bool> {
		return makeBindingTarget { $0.scrollsToTop = $1 }
	}
	#endif
}
