import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSTextView {
	private var notifications: Signal<Notification, NoError> {
		let name = NSTextView.didChangeNotification

		return NotificationCenter.default
			.reactive
			.notifications(forName: name, object: base)
			.take(during: lifetime)
	}

	/// A signal of values in `String` from the text field upon any changes.
	public var continuousStringValues: Signal<String, NoError> {
		return notifications
			.map { ($0.object as! NSTextView).string }
	}

	/// A signal of values in `NSAttributedString` from the text field upon any
	/// changes.
	public var continuousAttributedStringValues: Signal<NSAttributedString, NoError> {
		return notifications
			.map { ($0.object as! NSTextView).attributedString() }
	}

}
