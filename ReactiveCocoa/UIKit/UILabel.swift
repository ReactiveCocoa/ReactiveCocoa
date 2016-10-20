import ReactiveSwift
import UIKit

extension Reactive where Base: UILabel {
	/// Sets the text of the label.
	public var text: BindingTarget<String?> {
		return makeBindingTarget { $0.text = $1 }
	}

	/// Sets the attributed text of the label.
	public var attributedText: BindingTarget<NSAttributedString?> {
		return makeBindingTarget { $0.attributedText = $1 }
	}

	/// Sets the color of the text of the label.
	public var textColor: BindingTarget<UIColor> {
		return makeBindingTarget { $0.textColor = $1 }
	}
}
