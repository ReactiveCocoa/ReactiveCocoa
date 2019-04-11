import ReactiveSwift
import AppKit

extension Reactive where Base: NSView {
	/// Sets the visibility of the view.
	public var isHidden: BindingTarget<Bool> {
		return makeBindingTarget { $0.isHidden = $1 }
	}

	/// Sets the alpha value of the view.
	public var alphaValue: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.alphaValue = $1 }
	}
}
