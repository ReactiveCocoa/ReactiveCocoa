import ReactiveSwift
import UIKit
import enum Result.NoError

private class TextViewDelegateProxy: DelegateProxy<UITextViewDelegate>, UITextViewDelegate {
	@objc func textViewDidChangeSelection(_ textView: UITextView) {
		forwardee?.textViewDidChangeSelection?(textView)
	}
}

private extension UITextView {
    // Thunks to forward calls because key paths do not support implicit IUO to Optional
    // conversion.

    var _text: String? {
        get { return text }
        set { text = newValue }
    }

    var _attributedText: NSAttributedString? {
        get { return attributedText }
        set { attributedText = newValue }
    }
}

extension Reactive where Base: UITextView {
	private var proxy: TextViewDelegateProxy {
		return .proxy(for: base,
		              setter: #selector(setter: base.delegate),
		              getter: #selector(getter: base.delegate))
    }

	/// Sets the text of the text view.
	public var text: ValueBindable<Base, String?> {
        return ValueBindable(owner: base,
                             isEnabled: \.isEditable,
                             value: \._text,
                             values: { $0.reactive.textValues })
	}

	/// Sets the text of the text view.
	public var continuousText: ValueBindable<Base, String?> {
        return ValueBindable(owner: base,
                             isEnabled: \.isEditable,
                             value: \._text,
                             values: { $0.reactive.continuousTextValues })
	}

	private func textValues(forName name: NSNotification.Name) -> Signal<String?, NoError> {
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
	public var textValues: Signal<String?, NoError> {
		return textValues(forName: .UITextViewTextDidEndEditing)
	}

	/// A signal of text values emitted by the text view upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, NoError> {
		return textValues(forName: .UITextViewTextDidChange)
	}

	/// Sets the attributed text of the text view.
	public var attributedText: ValueBindable<Base, NSAttributedString?> {
        return ValueBindable(owner: base,
                             isEnabled: \.isEditable,
                             value: \._attributedText,
                             values: { $0.reactive.attributedTextValues })
	}

	/// Sets the attributed text of the text view.
	public var continuousAttributedText: ValueBindable<Base, NSAttributedString?> {
        return ValueBindable(owner: base,
                             isEnabled: \.isEditable,
                             value: \._attributedText,
                             values: { $0.reactive.continuousAttributedTextValues })
    }
	
	private func attributedTextValues(forName name: NSNotification.Name) -> Signal<NSAttributedString?, NoError> {
		return NotificationCenter.default
			.reactive
			.notifications(forName: name, object: base)
			.take(during: lifetime)
			.map { ($0.object as! UITextView).attributedText! }
	}
	
	/// A signal of attributed text values emitted by the text view upon end of editing.
	///
	/// - note: To observe attributed text values that change on all editing events,
	///   see `continuousAttributedTextValues`.
	public var attributedTextValues: Signal<NSAttributedString?, NoError> {
		return attributedTextValues(forName: .UITextViewTextDidEndEditing)
	}
	
	/// A signal of attributed text values emitted by the text view upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `attributedTextValues`.
	public var continuousAttributedTextValues: Signal<NSAttributedString?, NoError> {
		return attributedTextValues(forName: .UITextViewTextDidChange)
	}

	/// A signal of range values emitted by the text view upon any selection change.
	public var selectedRangeValues: Signal<NSRange, NoError> {
		return proxy.intercept(#selector(UITextViewDelegate.textViewDidChangeSelection))
			.map { [unowned base] in base.selectedRange }
	}
}
