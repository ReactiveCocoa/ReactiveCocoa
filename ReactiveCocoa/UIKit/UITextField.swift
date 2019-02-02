import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UITextField {
	/// Sets the text of the text field.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// A signal of text values emitted by the text field upon end of editing.
	///
	/// - note: To observe text values that change on all editing events,
	///   see `continuousTextValues`.
	public var textValues: Signal<String?, NoError> {
		return mapControlEvents([.editingDidEnd, .editingDidEndOnExit]) { $0.text }
	}

	/// A signal of text values emitted by the text field upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, NoError> {
		return mapControlEvents(.allEditingEvents) { $0.text }
	}
	
	/// Sets the attributed text of the text field.
	public var attributedText: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedText = $1 }
	}

	/// Sets the placeholder text of the text field.
	public var placeholder: BindingTarget<String?> {
		return makeBindingTarget { $0.placeholder = $1 }
	}
	
	/// Sets the textColor of the text field.
	public var textColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.textColor = $1 }
	}
	
	/// A signal of attributed text values emitted by the text field upon end of editing.
	///
	/// - note: To observe attributed text values that change on all editing events,
	///   see `continuousAttributedTextValues`.
	public var attributedTextValues: Signal<NSAttributedString?, NoError> {
		return mapControlEvents([.editingDidEnd, .editingDidEndOnExit]) { $0.attributedText }
	}
	
	/// A signal of attributed text values emitted by the text field upon any changes.
	///
	/// - note: To observe attributed text values only when editing ends, see `attributedTextValues`.
	public var continuousAttributedTextValues: Signal<NSAttributedString?, NoError> {
		return mapControlEvents(.allEditingEvents) { $0.attributedText }
	}

	/// Sets the secure text entry attribute on the text field.
	public var isSecureTextEntry: BindingTarget<Bool> {
		return makeBindingTarget { $0.isSecureTextEntry = $1 }
	}
}
