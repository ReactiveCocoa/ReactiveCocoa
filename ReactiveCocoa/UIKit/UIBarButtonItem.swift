import ReactiveSwift
import UIKit

extension Reactive where Base: UIBarButtonItem {
	/// The current associated action of `self`.
	private var associatedAction: Atomic<(action: CocoaAction<Base>, disposable: Disposable)?> {
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
				.disposable.dispose()
		}
	}
}
