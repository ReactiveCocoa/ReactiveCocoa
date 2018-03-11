import ReactiveSwift
import UIKit

protocol ReactiveUILabel {
	// Accessing the Text Attributes
	var text: BindingTarget<String?> { get }
	var attributedText: BindingTarget<NSAttributedString?> { get }
	var font: BindingTarget<UIFont> { get }
	var textColor: BindingTarget<UIColor> { get }
	var textAlignment: BindingTarget<NSTextAlignment> { get }
	var lineBreakMode: BindingTarget<NSLineBreakMode> { get }
	var isEnabled: BindingTarget<Bool> { get }
	// Sizing the Label's Text
	var adjustsFontSizeToFitWidth: BindingTarget<Bool> { get }
	@available(iOS 9, *)
	var allowsDefaultTighteningForTruncation: BindingTarget<Bool> { get }
	var baselineAdjustment: BindingTarget<UIBaselineAdjustment> { get }
	var minimumScaleFactor: BindingTarget<CGFloat> { get }
	var numberOfLines: BindingTarget<Int> { get }
	// Managing Highlight Values
	var highlightedTextColor: BindingTarget<UIColor>? { get }
	var isHighlighted: BindingTarget<Bool> { get }
	// Drawing a Shadow
	var shadowColor: BindingTarget<UIColor>? { get }
	var shadowOffset: BindingTarget<CGSize> { get }
	// Getting Layout Constraints
	var preferredMaxLayoutWidth: BindingTarget<CGFloat> { get }
	// Setting and getting Attributes
	var isUserInteractionEnabled: BindingTarget<Bool> { get }
}
