import ReactiveSwift
import UIKit

extension Reactive where Base: UIBarItem {
	/// Sets whether the bar item is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}

	/// Sets image of bar item.
	public var image: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.image = $1 }
	}

	/// Sets the title of bar item.
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.title = $1 }
	}
}
