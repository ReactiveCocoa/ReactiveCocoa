import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UISwitch {
	/// The action to be triggered when the switch is changed. It also controls
	/// the enabled state of the switch
	public var toggled: CocoaAction<Base>? {
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
	
	/// A signal of the enable state in `Bool` emitted by the switch.
	public var isEnableValues: Signal<Bool, NoError> {
		return controlEvents(.valueChanged).map { $0.isEnabled }
	}
	
	/// A property of on-off states in `Bool` emmited by the switch
	var isOnProperty: Property<Bool> {
		return Property(initial: base.isOn, then: self.isOnValues)
	}
	
	/// A property of the enable state in `Bool` emmited by the switch
	var isEnableProperty: Property<Bool> {
		return Property(initial: base.isEnabled, then: self.isEnableValues)
	}
}
