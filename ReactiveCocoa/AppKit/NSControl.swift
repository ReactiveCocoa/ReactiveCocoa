import ReactiveSwift
import AppKit

extension NSControl: ActionMessageSending {}

extension Reactive where Base: NSControl {
	/// Sets whether the control is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isEnabled = $1 }
	}

	/// Sets the value of the control with an `NSAttributedString`.
	public var attributedStringValue: BindingTarget<NSAttributedString> {
		return makeBindingTarget { $0.attributedStringValue = $1 }
	}

	/// A signal of values in `NSAttributedString`, emitted by the control.
	public var attributedStringValues: Signal<NSAttributedString, Never> {
		return proxy.invoked.map { $0.attributedStringValue }
	}

	/// Sets the value of the control with a `Bool`.
	public var boolValue: BindingTarget<Bool> {
		#if swift(>=4.0)
		return makeBindingTarget { $0.integerValue = $1 ? NSControl.StateValue.on.rawValue : NSControl.StateValue.off.rawValue }
		#else
		return makeBindingTarget { $0.integerValue = $1 ? NSOnState : NSOffState }
		#endif
	}

	/// A signal of values in `Bool`, emitted by the control.
	public var boolValues: Signal<Bool, Never> {
		#if swift(>=4.0)
		return proxy.invoked.map { $0.integerValue != NSControl.StateValue.off.rawValue }
		#else
		return proxy.invoked.map { $0.integerValue != NSOffState }
		#endif
	}

	/// Sets the value of the control with a `Double`.
	public var doubleValue: BindingTarget<Double> {
		return makeBindingTarget { $0.doubleValue = $1 }
	}

	/// A signal of values in `Double`, emitted by the control.
	public var doubleValues: Signal<Double, Never> {
		return proxy.invoked.map { $0.doubleValue }
	}

	/// Sets the value of the control with a `Float`.
	public var floatValue: BindingTarget<Float> {
		return makeBindingTarget { $0.floatValue = $1 }
	}

	/// A signal of values in `Float`, emitted by the control.
	public var floatValues: Signal<Float, Never> {
		return proxy.invoked.map { $0.floatValue }
	}

	/// Sets the value of the control with an `Int32`.
	public var intValue: BindingTarget<Int32> {
		return makeBindingTarget { $0.intValue = $1 }
	}

	/// A signal of values in `Int32`, emitted by the control.
	public var intValues: Signal<Int32, Never> {
		return proxy.invoked.map { $0.intValue }
	}

	/// Sets the value of the control with an `Int`.
	public var integerValue: BindingTarget<Int> {
		return makeBindingTarget { $0.integerValue = $1 }
	}

	/// A signal of values in `Int`, emitted by the control.
	public var integerValues: Signal<Int, Never> {
		return proxy.invoked.map { $0.integerValue }
	}

	/// Sets the value of the control.
	public var objectValue: BindingTarget<Any?> {
		return makeBindingTarget { $0.objectValue = $1 }
	}

	/// A signal of values in `Any?`, emitted by the control.
	public var objectValues: Signal<Any?, Never> {
		return proxy.invoked.map { $0.objectValue }
	}

	/// Sets the value of the control with a `String`.
	public var stringValue: BindingTarget<String> {
		return makeBindingTarget { $0.stringValue = $1 }
	}

	/// A signal of values in `String`, emitted by the control.
	public var stringValues: Signal<String, Never> {
		return proxy.invoked.map { $0.stringValue }
	}
}


