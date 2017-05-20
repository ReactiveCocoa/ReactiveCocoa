import ReactiveSwift
import enum Result.NoError
import UIKit

private extension UIRefreshControl {
    var _isRefreshing: Bool {
        get { return isRefreshing }
        set {
            if newValue {
                beginRefreshing()
            } else {
                endRefreshing()
            }
        }
    }
}

extension Reactive where Base: UIRefreshControl {
	/// Sets whether the refresh control should be refreshing.
	public var isRefreshing: ValueBindable<Base, Bool> {
		return makeValueBindable(value: \._isRefreshing,
		                         values: { $0.reactive.controlEvents(.valueChanged).map { $0.isRefreshing } },
		                         actionDidBind: { $2 += $0.reactive.isRefreshing <~ $1.isExecuting })
	}

	/// Sets the attributed title of the refresh control.
	public var attributedTitle: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedTitle = $1 }
	}
}
