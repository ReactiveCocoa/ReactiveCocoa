import ReactiveSwift

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Reactive where Base: NSLayoutConstraint {

	/// Sets the constant.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.constant)` instead.")
	public var constant: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.constant = $1 }
	}

}
