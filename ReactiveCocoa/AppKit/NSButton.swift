import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSButton {

	internal var associatedAction: Atomic<(action: CocoaAction<Base>, disposable: Disposable?)?> {
		return associatedValue { _ in Atomic(nil) }
	}

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
}
