#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UIResponder {
	/// Asks UIKit to make this object the first responder in its window.
	public var becomeFirstResponder: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.becomeFirstResponder() }
	}
	
	/// Notifies this object that it has been asked to relinquish its status as first responder in its window.
	public var resignFirstResponder: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.resignFirstResponder() }
	}
}
#endif
