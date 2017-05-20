import ReactiveSwift
import enum Result.NoError
import UIKit

extension UISwitch: ReactiveControlConfigurable {
	public static var defaultControlEvents: UIControlEvents {
		return .valueChanged
	}
}

extension Reactive where Base: UISwitch {
	/// Sets the on-off state of the switch.
	public var isOn: ValueBindable<Base, Bool> {
		return self[\.isOn]
	}

	/// A signal of on-off states in `Bool` emitted by the switch.
	public var isOnValues: Signal<Bool, NoError> {
		return map(\.isOn)
	}
}
