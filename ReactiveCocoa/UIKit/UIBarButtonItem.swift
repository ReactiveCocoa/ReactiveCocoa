#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UIBarButtonItem {
	/// The current associated action of `self`.
	private var associatedAction: Atomic<(action: CocoaAction<Base>, disposable: Disposable?)?> {
		return associatedValue { _ in Atomic(nil) }
	}

	/// The action to be triggered when the button is pressed. It also controls
	/// the enabled state of the button.
	public var pressed: CocoaAction<Base>? {
		get {
			return associatedAction.value?.action
		}

		nonmutating set {
			base.target = newValue
			base.action = newValue.map { _ in CocoaAction<Base>.selector }

			associatedAction
				.swap(newValue.map { action in
						let disposable = isEnabled <~ action.isEnabled
						return (action, disposable)
				})?
				.disposable?.dispose()
		}
	}

	/// Sets the style of the bar button item.
	public var style: BindingTarget<UIBarButtonItem.Style> {
		return makeBindingTarget { $0.style = $1 }
	}

	/// Sets the width of the bar button item.
	public var width: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.width = $1 }
	}

	/// Sets the possible titles of the bar button item.
	public var possibleTitles: BindingTarget<Set<String>?> {
		return makeBindingTarget { $0.possibleTitles = $1 }
	}

	/// Sets the custom view of the bar button item.
	public var customView: BindingTarget<UIView?> {
		return makeBindingTarget { $0.customView = $1 }
	}
}
#endif
