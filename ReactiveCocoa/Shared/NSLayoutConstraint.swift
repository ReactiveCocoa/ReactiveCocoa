#if !os(watchOS)
import ReactiveSwift

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#else
import UIKit
#endif

extension Reactive where Base: NSLayoutConstraint {

	/// Sets the constant.
	public var constant: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.constant = $1 }
	}

}
#endif
