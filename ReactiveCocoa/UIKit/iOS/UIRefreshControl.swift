import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UIRefreshControl {
	public var isRefreshing: BindingTarget<Bool> {
		return makeBindingTarget { $1 ? $0.beginRefreshing() : $0.endRefreshing() }
	}

	public var refresh: Signal<Void, NoError> {
		return trigger(for: .valueChanged)
	}
}
