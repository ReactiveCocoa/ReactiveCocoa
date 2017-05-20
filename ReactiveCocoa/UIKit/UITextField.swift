import ReactiveSwift
import enum Result.NoError
import UIKit

extension UITextField: ReactiveContinuousControlConfigurable {
	public static var defaultControlEvents: UIControlEvents {
		return [.editingDidEnd, .editingDidEndOnExit]
	}

	public static var defaultContinuousControlEvents: UIControlEvents {
		return .allEditingEvents
	}
}

extension Reactive where Base: UITextField {
	/// Sets the text of the text field.
	public var text: ValueBindable<Base, String?> {
		return self[\.text]
	}

	/// Sets the text of the text field.
	public var continuousText: ValueBindable<Base, String?> {
		return self[continuous: \.text]
	}

	/// A signal of text values emitted by the text field upon end of editing.
	///
	/// - note: To observe text values that change on all editing events,
	///   see `continuousTextValues`.
	public var textValues: Signal<String?, NoError> {
		return map(\.text)
	}

	/// A signal of text values emitted by the text field upon any changes.
	///
	/// - note: To observe text values only when editing ends, see `textValues`.
	public var continuousTextValues: Signal<String?, NoError> {
		return continuousMap(\.text)
	}

	/// Sets the attributed text of the text field.
	public var attributedText: ValueBindable<Base, NSAttributedString?> {
		return self[\.attributedText]
	}

	/// Sets the attributed text of the text field.
	public var continuousAttributedText: ValueBindable<Base, NSAttributedString?> {
		return self[continuous: \.attributedText]
	}
	
	/// Sets the textColor of the text field.
	public var textColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.textColor = $1 }
	}
	
	/// A signal of attributed text values emitted by the text field upon end of editing.
	///
	/// - note: To observe attributed text values that change on all editing events,
	///   see `continuousAttributedTextValues`.
	public var attributedTextValues: Signal<NSAttributedString?, NoError> {
		return map(\.attributedText)
	}
	
	/// A signal of attributed text values emitted by the text field upon any changes.
	///
	/// - note: To observe attributed text values only when editing ends, see `attributedTextValues`.
	public var continuousAttributedTextValues: Signal<NSAttributedString?, NoError> {
		return continuousMap(\.attributedText)
	}

	/// Sets the secure text entry attribute on the text field.
	public var isSecureTextEntry: BindingTarget<Bool> {
		return makeBindingTarget { $0.isSecureTextEntry = $1 }
	}
}
