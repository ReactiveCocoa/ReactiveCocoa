import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSTextView {
	private var notifications: Signal<Notification, NoError> {
		#if swift(>=4.0)
		let name = NSTextView.didChangeNotification
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
			.map { notification in
				let textView = notification.object as! NSTextView
				#if swift(>=4.0)
				return textView.string
				#else
				return textView.string ?? ""
				#endif
			}
	}

	/// A signal of values in `NSAttributedString` from the text field upon any
	/// changes.
	public var continuousAttributedStringValues: Signal<NSAttributedString, NoError> {
		return notifications
			.map { ($0.object as! NSTextView).attributedString() }
	}

}
