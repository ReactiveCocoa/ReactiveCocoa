import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceLabel {
	/// Sets the text of the label.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.setText($1) }
	}
	
	/// Sets the attributed text of the label.
	public var attributedText: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.setAttributedText($1) }
	}
	
	/// Sets the color of the text of the label.
	public var textColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.setTextColor($1) }
	}
}
