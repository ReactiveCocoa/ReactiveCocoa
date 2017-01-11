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
			associatedAction
				.swap(newValue.map { action in
					let disposable = CompositeDisposable()
					disposable += isEnabled <~ action.isEnabled
					disposable += trigger.observeValues { [unowned base = self.base] in
						action.execute(base)
					}
					return (action, disposable)
				})?
				.disposable?.dispose()
		}
	}
}
