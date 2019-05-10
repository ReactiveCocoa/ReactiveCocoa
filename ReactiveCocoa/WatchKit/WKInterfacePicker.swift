import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfacePicker {
	/// Sets the list of items of the picker.
	public var items: BindingTarget<[WKPickerItem]?> {
		return makeBindingTarget { $0.setItems($1) }
	}
	
	/// Sets the selected item index of the picker.
	public var selectedItemIndex: BindingTarget<Int> {
		return makeBindingTarget { $0.setSelectedItemIndex($1) }
	}
	
	/// Sets whether the picker is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.setEnabled($1) }
	}
}
