import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UISwitch {
	/// The action to be triggered when the switch is changed. It also controlls
	/// the enabled state of the switch
	public var valueChanged: CocoaAction<Base>? {
		get {
			return associatedAction.withValue { info in
				return info.flatMap { info in
					return info.controlEvents == .valueChanged ? info.action : nil
				}
			}
		}

		nonmutating set {
			setAction(newValue, for: .valueChanged)
		}
	}
	/// Sets the on-off state of the switch.
	public var isOn: BindingTarget<Bool> {
		return makeBindingTarget { $0.isOn = $1 }
	}

	/// A signal of on-off states in `Bool` emitted by the switch.
	public var isOnValues: Signal<Bool, NoError> {
		return controlEvents(.valueChanged).map { $0.isOn }
	}
}
