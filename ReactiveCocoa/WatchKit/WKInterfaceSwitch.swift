import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceSwitch {
	/// Sets the title of the switch.
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.setTitle($1) }
	}
	
	/// Sets the attributed title of the switch.
	public var attributedTitle: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.setAttributedTitle($1) }
	}
	
	/// Sets the color of the switch.
	public var color: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setColor($1) }
	}
	
	/// Sets whether the switch is on.
	public var isOn: BindingTarget<Bool> {
		return makeBindingTarget { $0.setOn($1) }
	}
	
	/// Sets whether the switch is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.setEnabled($1) }
	}
}
