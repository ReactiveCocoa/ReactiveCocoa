import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UIRefreshControl {
	/// Sets whether the refresh control should be refreshing.
	public var isRefreshing: BindingTarget<Bool> {
		return makeBindingTarget { $1 ? $0.beginRefreshing() : $0.endRefreshing() }
	}

	/// Sets the attributed title of the refresh control.
	public var attributedTitle: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedTitle = $1 }
	}

	/// A trigger that sends `next` when the user performs a refresh.
	public var refresh: Signal<Void, NoError> {
		return trigger(for: .valueChanged)
	}
}
