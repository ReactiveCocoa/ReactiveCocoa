import ReactiveSwift

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Reactive where Base: NSLayoutConstraint {

	public var constant: BindingTarget<CGFloat> {
		return makeBindingTarget(action: { $0.constant = $1 })
	}

}
