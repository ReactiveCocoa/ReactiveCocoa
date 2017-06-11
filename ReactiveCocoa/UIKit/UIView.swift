import ReactiveSwift
import UIKit

extension Reactive where Base: UIView {
	/// Sets the alpha value of the view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.alpha)` instead.")
	public var alpha: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.alpha = $1 }
	}

	/// Sets whether the view is hidden.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isHidden)` instead.")
	public var isHidden: BindingTarget<Bool> {
		return makeBindingTarget { $0.isHidden = $1 }
	}

	/// Sets whether the view accepts user interactions.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isUserInteractionEnabled)` instead.")
	public var isUserInteractionEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isUserInteractionEnabled = $1 }
	}

	/// Sets the background color of the view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.backgroundColor)` instead.")
	public var backgroundColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.backgroundColor = $1 }
	}
}
