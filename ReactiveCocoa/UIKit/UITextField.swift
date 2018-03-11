import ReactiveSwift
import enum Result.NoError
import UIKit

protocol ReactiveUITextField {
	// Accessing the Text Attributes
	var text: BindingTarget<String?> {get }
	var attributedText: BindingTarget<NSAttributedString?> {get }
	var placeholder: BindingTarget<String?> {get }
	var attributedPlaceholder: BindingTarget<NSAttributedString?> { get }
	var defaultTextAttributes: BindingTarget<[String : Any]> { get }
	var font: BindingTarget<UIFont?> { get }
	var textColor: BindingTarget<UIColor> {get }
	var textAlignment: BindingTarget<NSTextAlignment> { get }
	var typingAttributes: BindingTarget<[String : Any]?> { get }
	//  Sizing the Text Field's Text
	var adjustsFontSizeToFitWidth: BindingTarget<Bool> { get }
	var minimumFontSize: BindingTarget<CGFloat> { get }
	// Managing the Editing Behavior
	var clearsOnBeginEditing: BindingTarget<Bool> { get }
	var clearsOnInsertion: BindingTarget<Bool> { get }
	var allowsEditingTextAttributes: BindingTarget<Bool> { get }
	// Setting the View's Background Appearence
	var borderStyle: BindingTarget<UITextBorderStyle> { get }
	var background: BindingTarget<UIImage?> { get }
	var disabledBackground: BindingTarget<UIImage?> { get }
	// Managing Overlay Views
	var clearButtonMode: BindingTarget<UITextFieldViewMode> { get }
	var leftView: BindingTarget<UIView?> { get }
	var leftViewMode: BindingTarget<UITextFieldViewMode> { get }
	var rightView: BindingTarget<UIView?> { get }
	var rightViewMode: BindingTarget<UITextFieldViewMode> { get }
	// Replacing System Input View
	var inputView: BindingTarget<UIView?> { get }
	var inputAccessoryView: BindingTarget<UIView?> { get }
	
	var isSecureTextEntry: BindingTarget<Bool> { get }
}

extension Reactive where Base: UITextField {
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
}
