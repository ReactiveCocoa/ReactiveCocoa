import ReactiveSwift
import UIKit
import enum Result.NoError

extension Reactive where Base: UITextView {
	/// Sets the text of the text view.
	public var text: BindingTarget<String> {
		return makeBindingTarget { $0.text = $1 }
	}

	private func textValues(forName name: NSNotification.Name) -> Signal<String, NoError> {
		return NotificationCenter.default
			.reactive
			.notifications(forName: name, object: base)
			.take(during: lifetime)
			.map { ($0.object as! UITextView).text! }
	}

	/// A signal of text values emitted by the text view upon end of editing.
	///
	/// - note: To observe text values that change on all editing events,
	///   see `continuousTextValues`.
	public var textValues: Signal<String, NoError> {
		return textValues(forName: .UITextViewTextDidEndEditing)
	}

	/// A signal of text values emitted by the text view upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String, NoError> {
		return textValues(forName: .UITextViewTextDidChange)
	}
}
