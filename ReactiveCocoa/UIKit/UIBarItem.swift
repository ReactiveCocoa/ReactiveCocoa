import ReactiveSwift
import UIKit

extension Reactive where Base: UIBarItem {
	/// Sets whether the bar item is enabled.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isEnabled)` instead.")
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}

	/// Sets image of bar item.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.image)` instead.")
	public var image: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.image = $1 }
	}

	/// Sets the title of bar item.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.title)` instead.")
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.title = $1 }
	}
}
