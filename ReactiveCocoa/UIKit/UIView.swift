#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UIView {
	/// Sets the alpha value of the view.
	public var alpha: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.alpha = $1 }
	}

	/// Sets whether the view is hidden.
	public var isHidden: BindingTarget<Bool> {
		return makeBindingTarget { $0.isHidden = $1 }
	}

	/// Sets whether the view accepts user interactions.
	public var isUserInteractionEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isUserInteractionEnabled = $1 }
	}

	/// Sets the background color of the view.
	public var backgroundColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.backgroundColor = $1 }
	}
	
	/// Sets the tintColor of the view
	public var tintColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.tintColor = $1 }
	}
}
#endif
