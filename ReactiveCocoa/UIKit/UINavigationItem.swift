import ReactiveSwift
import UIKit

extension Reactive where Base: UINavigationItem {
	/// Sets the title of the navigation item.
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.title = $1 }
	}
	
	#if os(iOS)
		/// Sets the prompt of the navigation item.
		public var prompt: BindingTarget<String?> {
			return makeBindingTarget { $0.prompt = $1 }
		}
	#endif
}
