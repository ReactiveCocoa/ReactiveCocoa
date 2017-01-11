import ReactiveSwift
import enum Result.NoError
import AppKit

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
	public var attributedStringValues: Signal<NSAttributedString, NoError> {
		return trigger.map { [unowned base = self.base] in base.attributedStringValue }
	}

	/// Sets the value of the control with a `Bool`.
	public var boolValue: BindingTarget<Bool> {
		return makeBindingTarget { $0.integerValue = $1 ? NSOnState : NSOffState }
	}

	/// A signal of values in `Bool`, emitted by the control.
	public var boolValues: Signal<Bool, NoError> {
		return trigger.map { [unowned base = self.base] in
			return base.integerValue == NSOffState ? false : true
		}
	}

	/// Sets the value of the control with a `Double`.
	public var doubleValue: BindingTarget<Double> {
		return makeBindingTarget { $0.doubleValue = $1 }
	}

	/// A signal of values in `Double`, emitted by the control.
	public var doubleValues: Signal<Double, NoError> {
		return trigger.map { [unowned base = self.base] in base.doubleValue }
	}

	/// Sets the value of the control with a `Float`.
	public var floatValue: BindingTarget<Float> {
		return makeBindingTarget { $0.floatValue = $1 }
	}

	/// A signal of values in `Float`, emitted by the control.
	public var floatValues: Signal<Float, NoError> {
		return trigger.map { [unowned base = self.base] in base.floatValue }
	}

	/// Sets the value of the control with an `Int32`.
	public var intValue: BindingTarget<Int32> {
		return makeBindingTarget { $0.intValue = $1 }
	}

	/// A signal of values in `Int32`, emitted by the control.
	public var intValues: Signal<Int32, NoError> {
		return trigger.map { [unowned base = self.base] in base.intValue }
	}

	/// Sets the value of the control with an `Int`.
	public var integerValue: BindingTarget<Int> {
		return makeBindingTarget { $0.integerValue = $1 }
	}

	/// A signal of values in `Int`, emitted by the control.
	public var integerValues: Signal<Int, NoError> {
		return trigger.map { [unowned base = self.base] in base.integerValue }
	}

	/// Sets the value of the control.
	public var objectValue: BindingTarget<Any?> {
		return makeBindingTarget { $0.objectValue = $1 }
	}

	/// A signal of values in `Any?`, emitted by the control.
	public var objectValues: Signal<Any?, NoError> {
		return trigger.map { [unowned base = self.base] in base.objectValue }
	}

	/// Sets the value of the control with a `String`.
	public var stringValue: BindingTarget<String> {
		return makeBindingTarget { $0.stringValue = $1 }
	}

	/// A signal of values in `String`, emitted by the control.
	public var stringValues: Signal<String, NoError> {
		return trigger.map { [unowned base = self.base] in base.stringValue }
	}

	/// A trigger signal that sends a `next` event for every action messages
	/// received from the control, and completes when the control deinitializes.
	internal var trigger: Signal<(), NoError> {
		return associatedValue { base in
			let (signal, observer) = Signal<(), NoError>.pipe()

			let receiver = CocoaTarget(observer)
			base.target = receiver
			base.action = #selector(receiver.sendNext)

			lifetime.ended.observeCompleted {
				_ = receiver
				observer.sendCompleted()
			}

			return signal
		}
	}
}
