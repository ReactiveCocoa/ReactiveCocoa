#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

private class TextViewDelegateProxy: DelegateProxy<UITextViewDelegate>, UITextViewDelegate {
	@objc func textViewDidChangeSelection(_ textView: UITextView) {
		forwardee?.textViewDidChangeSelection?(textView)
	}
}

extension Reactive where Base: UITextView {
	private var proxy: TextViewDelegateProxy {
		return .proxy(for: base,
		              setter: #selector(setter: base.delegate),
		              getter: #selector(getter: base.delegate))
	}

	/// Sets the text of the text view.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	private func textValues(forName name: NSNotification.Name) -> Signal<String, Never> {
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
	public var textValues: Signal<String, Never> {
		return textValues(forName: UITextView.textDidEndEditingNotification)
	}

	/// A signal of text values emitted by the text view upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String, Never> {
		return textValues(forName: UITextView.textDidChangeNotification)
	}
	
	/// Sets the attributed text of the text view.
	public var attributedText: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedText = $1 }
	}
	
	private func attributedTextValues(forName name: NSNotification.Name) -> Signal<NSAttributedString, Never> {
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
	public var attributedTextValues: Signal<NSAttributedString, Never> {
		return attributedTextValues(forName: UITextView.textDidEndEditingNotification)
	}
	
	/// A signal of attributed text values emitted by the text view upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `attributedTextValues`.
	public var continuousAttributedTextValues: Signal<NSAttributedString, Never> {
		return attributedTextValues(forName: UITextView.textDidChangeNotification)
	}

	/// A signal of range values emitted by the text view upon any selection change.
	public var selectedRangeValues: Signal<NSRange, Never> {
		return proxy.intercept(#selector(UITextViewDelegate.textViewDidChangeSelection))
			.map { [unowned base] in base.selectedRange }
	}
}
#endif
