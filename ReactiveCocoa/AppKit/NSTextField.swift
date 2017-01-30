import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSTextField {
	private var notifications: Signal<Notification, NoError> {
		return NotificationCenter.default
			.reactive
			.notifications(forName: .NSControlTextDidChange, object: base)
			.take(during: lifetime)
	}

	/// A signal of values in `String` from the text field upon any changes.
	public var continuousStringValues: Signal<String, NoError> {
		return notifications
			.map { ($0.object as! NSTextField).stringValue }
	}

	/// A signal of values in `NSAttributedString` from the text field upon any
	/// changes.
	public var continuousAttributedStringValues: Signal<NSAttributedString, NoError> {
		return notifications
			.map { ($0.object as! NSTextField).attributedStringValue }
	}

	/// Wraps the `stringValue` binding target from NSControl for
	/// cross-platform compatibility
	public var text: BindingTarget<String> {
		return stringValue
	}

	/// Wraps the `stringValue` binding target from NSControl for
	/// cross-platform compatibility
	public var attributedText: BindingTarget<NSAttributedString> {
		return attributedStringValue
	}
}
