import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSTextField {
	private var notifications: Signal<Notification, NoError> {
		#if swift(>=4.0)
		let name = NSControl.textDidChangeNotification
		#else
		let name = Notification.Name.NSControlTextDidChange
		#endif

		return NotificationCenter.default
			.reactive
			.notifications(forName: name, object: base)
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

	/// Sets the color of the text with an `NSColor`.
	public var textColor: BindingTarget<NSColor> {
		return makeBindingTarget { $0.textColor = $1 }
	}
}
