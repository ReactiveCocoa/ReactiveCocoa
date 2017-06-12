import ReactiveSwift
import UIKit

extension Reactive where Base: UITabBarItem {
	/// Sets the badge value of the tab bar item.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.badgeValue)` instead.")
	public var badgeValue: BindingTarget<String?> {
		return makeBindingTarget { $0.badgeValue = $1 }
	}
	
	
	/// Sets the badge color of the tab bar item.
	@available(iOS 10, *)
	@available(tvOS 10, *)
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.badgeColor)` instead.")
	public var badgeColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.badgeColor = $1 }
	}
}
