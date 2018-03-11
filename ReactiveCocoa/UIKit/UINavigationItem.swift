import ReactiveSwift
import UIKit

protocol ReactiveUINavigationItem {
	var title: BindingTarget<String?> { get }
}

extension Reactive where Base: UINavigationItem {
	#if os(iOS)
		/// Sets the prompt of the navigation item.
		public var prompt: BindingTarget<String?> {
			return makeBindingTarget { $0.prompt = $1 }
		}
	#endif
}
