import ReactiveSwift
import UIKit

extension Reactive where Base: UINavigationItem {
	/// Sets the title of the navigation item.
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.title = $1 }
	}

	/// Sets the title view of the navigation item.
	public var titleView: BindingTarget<UIView?> {
		return makeBindingTarget { $0.titleView = $1 }
	}

#if os(iOS)
	/// Sets the prompt of the navigation item.
	public var prompt: BindingTarget<String?> {
		return makeBindingTarget { $0.prompt = $1 }
	}

	/// Sets the back button item of the navigation item.
	public var backBarButtonItem: BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.backBarButtonItem = $1 }
	}

	/// Sets the `hidesBackButton` property of the navigation item.
	public var hidesBackButton: BindingTarget<Bool> {
		return makeBindingTarget { $0.hidesBackButton = $1 }
	}
#endif

	/// Sets the left bar button items of the navigation item.
	public var leftBarButtonItems: BindingTarget<[UIBarButtonItem]?> {
		return makeBindingTarget { $0.leftBarButtonItems = $1 }
	}

	/// Sets the right bar button items of the navigation item.
	public var rightBarButtonItems: BindingTarget<[UIBarButtonItem]?> {
		return makeBindingTarget { $0.rightBarButtonItems = $1 }
	}

	/// Sets the left bar button item of the navigation item.
	public var leftBarButtonItem: BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.leftBarButtonItem = $1 }
	}

	/// Sets the right bar button item of the navigation item.
	public var rightBarButtonItem: BindingTarget<UIBarButtonItem?> {
		return makeBindingTarget { $0.rightBarButtonItem = $1 }
	}

#if os(iOS)
	/// Sets the `leftItemsSupplementBackButton` property of the navigation item.
	@available(iOS 5.0, *)
	public var leftItemsSupplementBackButton: BindingTarget<Bool> {
		return makeBindingTarget { $0.leftItemsSupplementBackButton = $1 }
	}

	/// Sets the large title display mode of the navigation item.
	@available(iOS 11.0, *)
	public var largeTitleDisplayMode: BindingTarget<UINavigationItem.LargeTitleDisplayMode> {
		return makeBindingTarget { $0.largeTitleDisplayMode = $1 }
	}

	/// Sets the search controller of the navigation item.
	@available(iOS 11.0, *)
	public var searchController: BindingTarget<UISearchController?> {
		return makeBindingTarget { $0.searchController = $1 }
	}

	/// Sets the `hidesSearchBarWhenScrolling` property of the navigation item.
	@available(iOS 11.0, *)
	public var hidesSearchBarWhenScrolling: BindingTarget<Bool> {
		return makeBindingTarget { $0.hidesSearchBarWhenScrolling = $1 }
	}
#endif
}
