import ReactiveSwift
import UIKit

protocol ReactiveUITabBarItem {
	var badgeValue: BindingTarget<String?> { get }
}

extension Reactive where Base: UITabBarItem {
	/// Sets the badge color of the tab bar item.
	// Sourcery currently does not capture all @available attributes, see https://github.com/krzysztofzablocki/Sourcery/issues/540
	@available(iOS 10, *)
	@available(tvOS 10, *)
	public var badgeColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.badgeColor = $1 }
	}
}
