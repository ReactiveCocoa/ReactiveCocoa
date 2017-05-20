import ReactiveSwift
import Result
import UIKit

extension Reactive where Base: UIBarButtonItem {
	/// The current associated action of `self`.
	private var presses: Signal<Base, NoError> {
		return associatedValue { base in
			let (signal, observer) = Signal<Base, NoError>.pipe()
			let target = CocoaTarget(observer, transform: { $0 as! Base })
			base.target = target
			base.action = #selector(target.invoke)

			return signal
		}
	}

	/// The action to be triggered when the button is pressed. It also controls
	/// the enabled state of the button.
	public var pressed: ActionBindable<Base, Void> {
		return ActionBindable(owner: base,
		                      isEnabled: \.isEnabled,
							  values: { $0.reactive.presses.map { _ in } })
	}
}
