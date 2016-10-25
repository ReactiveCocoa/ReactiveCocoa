import ReactiveSwift
import UIKit

extension Reactive where Base: UIBarItem {
	/// Sets whether the bar item is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}
}
