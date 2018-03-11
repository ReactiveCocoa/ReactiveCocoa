import ReactiveSwift
import UIKit
import enum Result.NoError

private class TextViewDelegateProxy: DelegateProxy<UITextViewDelegate>, UITextViewDelegate {
	@objc func textViewDidChangeSelection(_ textView: UITextView) {
		forwardee?.textViewDidChangeSelection?(textView)
	}
}

protocol ReactiveUITextView {
	// Configuring the Text Attributes
	var text: BindingTarget<String?> { get }
	var attributedText: BindingTarget<NSAttributedString?> { get }
	var font: BindingTarget<UIFont?> { get }
	var textColor: BindingTarget<UIColor?> { get }
	var isEditable: BindingTarget<Bool> { get }
	var allowsEditingTextAttributes: BindingTarget<Bool> { get }
	var dataDetectorTypes: BindingTarget<UIDataDetectorTypes> { get }
	var textAlignment: BindingTarget<NSTextAlignment> { get }
	var typingAttributes: BindingTarget<[String : Any]> { get }
	var linkTextAttributes: BindingTarget<[String : Any]> { get }
	var textContainerInset: BindingTarget<UIEdgeInsets> { get }
	// Working with the Selection
	var selectedRange: BindingTarget<NSRange> { get }
	var clearsOnInsertion: BindingTarget<Bool> { get }
	var isSelectable: BindingTarget<Bool> { get }
	// Replacing the System Input View
	var inputView: BindingTarget<UIView?> { get }
	var inputAccessoryView: BindingTarget<UIView?> { get }
}

extension Reactive where Base: UITextView {
	private var proxy: TextViewDelegateProxy {
		return .proxy(for: base,
		              setter: #selector(setter: base.delegate),
		              getter: #selector(getter: base.delegate))
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
