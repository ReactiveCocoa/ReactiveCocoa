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

	/// The action to be triggered when the refresh control is refreshed. It
	/// also controls the enabled and refreshing states of the refresh control.
	public var refreshed: CocoaAction<Base>? {
		get {
			return associatedAction.withValue { info in
				return info.flatMap { info in
					return info.controlEvents == .valueChanged ? info.action : nil
				}
			}
		}

		nonmutating set {
			associatedAction.modify { associatedAction in
				associatedAction?.disposable.dispose()

				let controlEvents = UIControlEvents.valueChanged

				if let action = newValue {
					base.addTarget(action, action: CocoaAction<Base>.selector, for: controlEvents)

					let disposable = CompositeDisposable()
					disposable += isEnabled <~ action.isEnabled
					disposable += isRefreshing <~ action.isExecuting
					disposable += { [weak base = self.base] in
						base?.removeTarget(action, action: CocoaAction<Base>.selector, for: controlEvents)
					}

					associatedAction = (action, controlEvents, ScopedDisposable(disposable))
				} else {
					associatedAction = nil
				}
			}
		}
	}
}
