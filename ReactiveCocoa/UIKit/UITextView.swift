import ReactiveSwift
import UIKit
import enum Result.NoError

extension Reactive where Base: UITextView {
	/// Sets the text of the text view.
	public var text: BindingTarget<String> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// A signal of text values emitted by the text view upon end of editing.
	public var textValues: Signal<String, NoError> {
		return NotificationCenter.default
			.reactive
			.notifications(forName: .UITextViewTextDidEndEditing, object: base)
			.take(during: lifetime)
			.map { ($0.object as! UITextView).text! }
	}

	/// A signal of text values emitted by the text view upon any changes.
	public var continuousTextValues: Signal<String, NoError> {
		return NotificationCenter.default
			.reactive
			.notifications(forName: .UITextViewTextDidChange, object: base)
			.take(during: lifetime)
			.map { ($0.object as! UITextView).text! }
	}
}
