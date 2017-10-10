import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSButton {

	internal var associatedAction: Atomic<(action: CocoaAction<Base>, disposable: CompositeDisposable)?> {
		return associatedValue { _ in Atomic(nil) }
	}

	public var pressed: CocoaAction<Base>? {
		get {
			return associatedAction.value?.action
		}

		nonmutating set {
			associatedAction
				.modify { action in
					action?.disposable.dispose()
					action = newValue.map { action in
						let disposable = CompositeDisposable()
						disposable += isEnabled <~ action.isEnabled
						disposable += proxy.invoked.observeValues(action.execute)
						return (action, disposable)
					}
			}
		}
	}

	#if swift(>=4.0)
	/// A signal of integer states (On, Off, Mixed), emitted by the button.
	public var states: Signal<NSControl.StateValue, NoError> {
		return proxy.invoked.map { $0.state }
	}

	/// Sets the button's state
	public var state: BindingTarget<NSControl.StateValue> {
		return makeBindingTarget { $0.state = $1 }
	}
	#else
	/// A signal of integer states (On, Off, Mixed), emitted by the button.
	public var states: Signal<Int, NoError> {
		return proxy.invoked.map { $0.state }
	}

	/// Sets the button's state
	public var state: BindingTarget<Int> {
		return makeBindingTarget { $0.state = $1 }
	}
	#endif

	/// Sets the button's image
	public var image: BindingTarget<NSImage?> {
		return makeBindingTarget { $0.image = $1 }
	}
}
