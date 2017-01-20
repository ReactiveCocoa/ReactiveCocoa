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

	/// Sets the color of the text with an `NSColor`.
	public var textColor: BindingTarget<NSColor> {
		return makeBindingTarget { $0.textColor = $1 }
	}
}
