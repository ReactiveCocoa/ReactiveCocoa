#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UINavigationBar {
	/// Sets the barTintColor of the navigation bar.
	public var barTintColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.barTintColor = $1 }
	}
}
#endif
