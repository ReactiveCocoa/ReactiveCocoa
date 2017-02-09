import ReactiveSwift
import enum Result.NoError
import UIKit

private class PickerViewDelegateProxy: DelegateProxy<UIPickerViewDelegate>, UIPickerViewDelegate {
	@objc func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		forwardee?.pickerView?(pickerView, didSelectRow: row, inComponent: component)
	}
}

extension Reactive where Base: UIPickerView {

	private var proxy: PickerViewDelegateProxy {
		return .proxy(for: base,
		              setter: #selector(setter: base.delegate),
		              getter: #selector(getter: base.delegate))
	}

	/// Sets the selected row in the specified component, without animating the
	/// position.
	public func selectedRow(inComponent component: Int) -> BindingTarget<Int> {
		return makeBindingTarget { $0.selectRow($1, inComponent: component, animated: false) }
	}

	/// Reloads all components
	public var reloadAllComponents: BindingTarget<()> {
		return makeBindingTarget { base, _ in base.reloadAllComponents() }
	}

	/// Reloads the specified component
	public var reloadComponent: BindingTarget<Int> {
		return makeBindingTarget { $0.reloadComponent($1) }
	}

	/// Create a signal which sends a `value` event for each row selection
	///
	/// - returns:
	///   A trigger signal.
	public var selections: Signal<(row: Int, component: Int), NoError> {
		return proxy.intercept(#selector(UIPickerViewDelegate.pickerView(_:didSelectRow:inComponent:)))
			.map { (row: $0[1] as! Int, component: $0[2] as! Int) }
	}
}
