import ReactiveSwift
import UIKit

protocol ReactiveUIScrollView {
	var contentInset: BindingTarget<UIEdgeInsets> { get }
	var scrollIndicatorInsets: BindingTarget<UIEdgeInsets> { get }
	var isScrollEnabled: BindingTarget<Bool> { get }
	var zoomScale: BindingTarget<CGFloat> { get }
	var minimumZoomScale: BindingTarget<CGFloat> { get }
	var maximumZoomScale: BindingTarget<CGFloat> { get }
}

extension Reactive where Base: UIScrollView {

	
	#if os(iOS)
	/// Sets whether the scroll view scrolls to the top when the menu is tapped.
	public var scrollsToTop: BindingTarget<Bool> {
		return makeBindingTarget { $0.scrollsToTop = $1 }
	}
	#endif
}
