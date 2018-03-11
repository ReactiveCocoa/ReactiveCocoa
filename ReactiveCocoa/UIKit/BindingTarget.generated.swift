// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import ReactiveSwift
import UIKit


extension Reactive where Base: UIBarItem {
  /// Sets the isEnabled of the barItem
  public var isEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isEnabled = $1 }
  }

  /// Sets the image of the barItem
  public var image: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.image = $1 }
  }

  /// Sets the title of the barItem
  public var title: BindingTarget<String?> {
    return makeBindingTarget { $0.title = $1 }
  }

}

extension Reactive where Base: UIControl {
  /// Sets the isEnabled of the control
  public var isEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isEnabled = $1 }
  }

  /// Sets the isSelected of the control
  public var isSelected: BindingTarget<Bool> {
    return makeBindingTarget { $0.isSelected = $1 }
  }

  /// Sets the isHighlighted of the control
  public var isHighlighted: BindingTarget<Bool> {
    return makeBindingTarget { $0.isHighlighted = $1 }
  }

  /// Sets the contentVerticalAlignment of the control
  public var contentVerticalAlignment: BindingTarget<UIControlContentVerticalAlignment> {
    return makeBindingTarget { $0.contentVerticalAlignment = $1 }
  }

  /// Sets the contentHorizontalAlignment of the control
  public var contentHorizontalAlignment: BindingTarget<UIControlContentHorizontalAlignment> {
    return makeBindingTarget { $0.contentHorizontalAlignment = $1 }
  }

}

extension Reactive where Base: UIImageView {
  /// Sets the image of the imageView
  public var image: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.image = $1 }
  }

  /// Sets the highlightedImage of the imageView
  public var highlightedImage: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.highlightedImage = $1 }
  }

}

extension Reactive where Base: UILabel {
  /// Sets the text of the label
  public var text: BindingTarget<String?> {
    return makeBindingTarget { $0.text = $1 }
  }

  /// Sets the attributedText of the label
  public var attributedText: BindingTarget<NSAttributedString?> {
    return makeBindingTarget { $0.attributedText = $1 }
  }

  /// Sets the font of the label
  public var font: BindingTarget<UIFont> {
    return makeBindingTarget { $0.font = $1 }
  }

  /// Sets the textColor of the label
  public var textColor: BindingTarget<UIColor> {
    return makeBindingTarget { $0.textColor = $1 }
  }

  /// Sets the textAlignment of the label
  public var textAlignment: BindingTarget<NSTextAlignment> {
    return makeBindingTarget { $0.textAlignment = $1 }
  }

  /// Sets the lineBreakMode of the label
  public var lineBreakMode: BindingTarget<NSLineBreakMode> {
    return makeBindingTarget { $0.lineBreakMode = $1 }
  }

  /// Sets the isEnabled of the label
  public var isEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isEnabled = $1 }
  }

  /// Sets the adjustsFontSizeToFitWidth of the label
  public var adjustsFontSizeToFitWidth: BindingTarget<Bool> {
    return makeBindingTarget { $0.adjustsFontSizeToFitWidth = $1 }
  }

  /// Sets the allowsDefaultTighteningForTruncation of the label
  @available(iOS 9, *)
  public var allowsDefaultTighteningForTruncation: BindingTarget<Bool> {
    return makeBindingTarget { $0.allowsDefaultTighteningForTruncation = $1 }
  }

  /// Sets the baselineAdjustment of the label
  public var baselineAdjustment: BindingTarget<UIBaselineAdjustment> {
    return makeBindingTarget { $0.baselineAdjustment = $1 }
  }

  /// Sets the minimumScaleFactor of the label
  public var minimumScaleFactor: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.minimumScaleFactor = $1 }
  }

  /// Sets the numberOfLines of the label
  public var numberOfLines: BindingTarget<Int> {
    return makeBindingTarget { $0.numberOfLines = $1 }
  }

  /// Sets the highlightedTextColor of the label
  public var highlightedTextColor: BindingTarget<UIColor>? {
    return makeBindingTarget { $0.highlightedTextColor = $1 }
  }

  /// Sets the isHighlighted of the label
  public var isHighlighted: BindingTarget<Bool> {
    return makeBindingTarget { $0.isHighlighted = $1 }
  }

  /// Sets the shadowColor of the label
  public var shadowColor: BindingTarget<UIColor>? {
    return makeBindingTarget { $0.shadowColor = $1 }
  }

  /// Sets the shadowOffset of the label
  public var shadowOffset: BindingTarget<CGSize> {
    return makeBindingTarget { $0.shadowOffset = $1 }
  }

  /// Sets the preferredMaxLayoutWidth of the label
  public var preferredMaxLayoutWidth: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.preferredMaxLayoutWidth = $1 }
  }

  /// Sets the isUserInteractionEnabled of the label
  public var isUserInteractionEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isUserInteractionEnabled = $1 }
  }

}

extension Reactive where Base: UINavigationItem {
  /// Sets the title of the navigationItem
  public var title: BindingTarget<String?> {
    return makeBindingTarget { $0.title = $1 }
  }

}

extension Reactive where Base: UIProgressView {
  /// Sets the progress of the progressView
  public var progress: BindingTarget<Float> {
    return makeBindingTarget { $0.progress = $1 }
  }

  /// Sets the observedProgress of the progressView
  @available(iOS 9, *)
  public var observedProgress: BindingTarget<Progress?> {
    return makeBindingTarget { $0.observedProgress = $1 }
  }

  /// Sets the progressViewStyle of the progressView
  public var progressViewStyle: BindingTarget<UIProgressViewStyle> {
    return makeBindingTarget { $0.progressViewStyle = $1 }
  }

  /// Sets the progressTintColor of the progressView
  public var progressTintColor: BindingTarget<UIColor?> {
    return makeBindingTarget { $0.progressTintColor = $1 }
  }

  /// Sets the progressImage of the progressView
  public var progressImage: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.progressImage = $1 }
  }

  /// Sets the trackTintColor of the progressView
  public var trackTintColor: BindingTarget<UIColor?> {
    return makeBindingTarget { $0.trackTintColor = $1 }
  }

  /// Sets the trackImage of the progressView
  public var trackImage: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.trackImage = $1 }
  }

}

extension Reactive where Base: UIScrollView {
  /// Sets the contentInset of the scrollView
  public var contentInset: BindingTarget<UIEdgeInsets> {
    return makeBindingTarget { $0.contentInset = $1 }
  }

  /// Sets the scrollIndicatorInsets of the scrollView
  public var scrollIndicatorInsets: BindingTarget<UIEdgeInsets> {
    return makeBindingTarget { $0.scrollIndicatorInsets = $1 }
  }

  /// Sets the isScrollEnabled of the scrollView
  public var isScrollEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isScrollEnabled = $1 }
  }

  /// Sets the zoomScale of the scrollView
  public var zoomScale: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.zoomScale = $1 }
  }

  /// Sets the minimumZoomScale of the scrollView
  public var minimumZoomScale: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.minimumZoomScale = $1 }
  }

  /// Sets the maximumZoomScale of the scrollView
  public var maximumZoomScale: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.maximumZoomScale = $1 }
  }

}

extension Reactive where Base: UISegmentedControl {
  /// Sets the selectedSegmentIndex of the segmentedControl
  public var selectedSegmentIndex: BindingTarget<Int> {
    return makeBindingTarget { $0.selectedSegmentIndex = $1 }
  }

}

extension Reactive where Base: UITabBarItem {
  /// Sets the badgeValue of the tabBarItem
  public var badgeValue: BindingTarget<String?> {
    return makeBindingTarget { $0.badgeValue = $1 }
  }

}

extension Reactive where Base: UITextField {
  /// Sets the text of the textField
  public var text: BindingTarget<String?> {
    return makeBindingTarget { $0.text = $1 }
  }

  /// Sets the attributedText of the textField
  public var attributedText: BindingTarget<NSAttributedString?> {
    return makeBindingTarget { $0.attributedText = $1 }
  }

  /// Sets the placeholder of the textField
  public var placeholder: BindingTarget<String?> {
    return makeBindingTarget { $0.placeholder = $1 }
  }

  /// Sets the attributedPlaceholder of the textField
  public var attributedPlaceholder: BindingTarget<NSAttributedString?> {
    return makeBindingTarget { $0.attributedPlaceholder = $1 }
  }

  /// Sets the defaultTextAttributes of the textField
  public var defaultTextAttributes: BindingTarget<[String : Any]> {
    return makeBindingTarget { $0.defaultTextAttributes = $1 }
  }

  /// Sets the font of the textField
  public var font: BindingTarget<UIFont?> {
    return makeBindingTarget { $0.font = $1 }
  }

  /// Sets the textColor of the textField
  public var textColor: BindingTarget<UIColor> {
    return makeBindingTarget { $0.textColor = $1 }
  }

  /// Sets the textAlignment of the textField
  public var textAlignment: BindingTarget<NSTextAlignment> {
    return makeBindingTarget { $0.textAlignment = $1 }
  }

  /// Sets the typingAttributes of the textField
  public var typingAttributes: BindingTarget<[String : Any]?> {
    return makeBindingTarget { $0.typingAttributes = $1 }
  }

  /// Sets the adjustsFontSizeToFitWidth of the textField
  public var adjustsFontSizeToFitWidth: BindingTarget<Bool> {
    return makeBindingTarget { $0.adjustsFontSizeToFitWidth = $1 }
  }

  /// Sets the minimumFontSize of the textField
  public var minimumFontSize: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.minimumFontSize = $1 }
  }

  /// Sets the clearsOnBeginEditing of the textField
  public var clearsOnBeginEditing: BindingTarget<Bool> {
    return makeBindingTarget { $0.clearsOnBeginEditing = $1 }
  }

  /// Sets the clearsOnInsertion of the textField
  public var clearsOnInsertion: BindingTarget<Bool> {
    return makeBindingTarget { $0.clearsOnInsertion = $1 }
  }

  /// Sets the allowsEditingTextAttributes of the textField
  public var allowsEditingTextAttributes: BindingTarget<Bool> {
    return makeBindingTarget { $0.allowsEditingTextAttributes = $1 }
  }

  /// Sets the borderStyle of the textField
  public var borderStyle: BindingTarget<UITextBorderStyle> {
    return makeBindingTarget { $0.borderStyle = $1 }
  }

  /// Sets the background of the textField
  public var background: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.background = $1 }
  }

  /// Sets the disabledBackground of the textField
  public var disabledBackground: BindingTarget<UIImage?> {
    return makeBindingTarget { $0.disabledBackground = $1 }
  }

  /// Sets the clearButtonMode of the textField
  public var clearButtonMode: BindingTarget<UITextFieldViewMode> {
    return makeBindingTarget { $0.clearButtonMode = $1 }
  }

  /// Sets the leftView of the textField
  public var leftView: BindingTarget<UIView?> {
    return makeBindingTarget { $0.leftView = $1 }
  }

  /// Sets the leftViewMode of the textField
  public var leftViewMode: BindingTarget<UITextFieldViewMode> {
    return makeBindingTarget { $0.leftViewMode = $1 }
  }

  /// Sets the rightView of the textField
  public var rightView: BindingTarget<UIView?> {
    return makeBindingTarget { $0.rightView = $1 }
  }

  /// Sets the rightViewMode of the textField
  public var rightViewMode: BindingTarget<UITextFieldViewMode> {
    return makeBindingTarget { $0.rightViewMode = $1 }
  }

  /// Sets the inputView of the textField
  public var inputView: BindingTarget<UIView?> {
    return makeBindingTarget { $0.inputView = $1 }
  }

  /// Sets the inputAccessoryView of the textField
  public var inputAccessoryView: BindingTarget<UIView?> {
    return makeBindingTarget { $0.inputAccessoryView = $1 }
  }

  /// Sets the isSecureTextEntry of the textField
  public var isSecureTextEntry: BindingTarget<Bool> {
    return makeBindingTarget { $0.isSecureTextEntry = $1 }
  }

}

extension Reactive where Base: UITextView {
  /// Sets the text of the textView
  public var text: BindingTarget<String?> {
    return makeBindingTarget { $0.text = $1 }
  }

  /// Sets the attributedText of the textView
  public var attributedText: BindingTarget<NSAttributedString?> {
    return makeBindingTarget { $0.attributedText = $1 }
  }

  /// Sets the font of the textView
  public var font: BindingTarget<UIFont?> {
    return makeBindingTarget { $0.font = $1 }
  }

  /// Sets the textColor of the textView
  public var textColor: BindingTarget<UIColor?> {
    return makeBindingTarget { $0.textColor = $1 }
  }

  /// Sets the isEditable of the textView
  public var isEditable: BindingTarget<Bool> {
    return makeBindingTarget { $0.isEditable = $1 }
  }

  /// Sets the allowsEditingTextAttributes of the textView
  public var allowsEditingTextAttributes: BindingTarget<Bool> {
    return makeBindingTarget { $0.allowsEditingTextAttributes = $1 }
  }

  /// Sets the dataDetectorTypes of the textView
  public var dataDetectorTypes: BindingTarget<UIDataDetectorTypes> {
    return makeBindingTarget { $0.dataDetectorTypes = $1 }
  }

  /// Sets the textAlignment of the textView
  public var textAlignment: BindingTarget<NSTextAlignment> {
    return makeBindingTarget { $0.textAlignment = $1 }
  }

  /// Sets the typingAttributes of the textView
  public var typingAttributes: BindingTarget<[String : Any]> {
    return makeBindingTarget { $0.typingAttributes = $1 }
  }

  /// Sets the linkTextAttributes of the textView
  public var linkTextAttributes: BindingTarget<[String : Any]> {
    return makeBindingTarget { $0.linkTextAttributes = $1 }
  }

  /// Sets the textContainerInset of the textView
  public var textContainerInset: BindingTarget<UIEdgeInsets> {
    return makeBindingTarget { $0.textContainerInset = $1 }
  }

  /// Sets the selectedRange of the textView
  public var selectedRange: BindingTarget<NSRange> {
    return makeBindingTarget { $0.selectedRange = $1 }
  }

  /// Sets the clearsOnInsertion of the textView
  public var clearsOnInsertion: BindingTarget<Bool> {
    return makeBindingTarget { $0.clearsOnInsertion = $1 }
  }

  /// Sets the isSelectable of the textView
  public var isSelectable: BindingTarget<Bool> {
    return makeBindingTarget { $0.isSelectable = $1 }
  }

  /// Sets the inputView of the textView
  public var inputView: BindingTarget<UIView?> {
    return makeBindingTarget { $0.inputView = $1 }
  }

  /// Sets the inputAccessoryView of the textView
  public var inputAccessoryView: BindingTarget<UIView?> {
    return makeBindingTarget { $0.inputAccessoryView = $1 }
  }

}

extension Reactive where Base: UIView {
  /// Sets the backgroundColor of the view
  public var backgroundColor: BindingTarget<UIColor> {
    return makeBindingTarget { $0.backgroundColor = $1 }
  }

  /// Sets the isHidden of the view
  public var isHidden: BindingTarget<Bool> {
    return makeBindingTarget { $0.isHidden = $1 }
  }

  /// Sets the alpha of the view
  public var alpha: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.alpha = $1 }
  }

  /// Sets the isOpaque of the view
  public var isOpaque: BindingTarget<Bool> {
    return makeBindingTarget { $0.isOpaque = $1 }
  }

  /// Sets the tintColor of the view
  public var tintColor: BindingTarget<UIColor> {
    return makeBindingTarget { $0.tintColor = $1 }
  }

  /// Sets the tintAdjustmentMode of the view
  public var tintAdjustmentMode: BindingTarget<UIViewTintAdjustmentMode> {
    return makeBindingTarget { $0.tintAdjustmentMode = $1 }
  }

  /// Sets the clipsToBounds of the view
  public var clipsToBounds: BindingTarget<Bool> {
    return makeBindingTarget { $0.clipsToBounds = $1 }
  }

  /// Sets the clearsContextBeforeDrawing of the view
  public var clearsContextBeforeDrawing: BindingTarget<Bool> {
    return makeBindingTarget { $0.clearsContextBeforeDrawing = $1 }
  }

  /// Sets the mask of the view
  public var mask: BindingTarget<UIView?> {
    return makeBindingTarget { $0.mask = $1 }
  }

  /// Sets the isUserInteractionEnabled of the view
  public var isUserInteractionEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isUserInteractionEnabled = $1 }
  }

  /// Sets the isMultipleTouchEnabled of the view
  public var isMultipleTouchEnabled: BindingTarget<Bool> {
    return makeBindingTarget { $0.isMultipleTouchEnabled = $1 }
  }

  /// Sets the isExclusiveTouch of the view
  public var isExclusiveTouch: BindingTarget<Bool> {
    return makeBindingTarget { $0.isExclusiveTouch = $1 }
  }

  /// Sets the frame of the view
  public var frame: BindingTarget<CGRect> {
    return makeBindingTarget { $0.frame = $1 }
  }

  /// Sets the bounds of the view
  public var bounds: BindingTarget<CGRect> {
    return makeBindingTarget { $0.bounds = $1 }
  }

  /// Sets the center of the view
  public var center: BindingTarget<CGPoint> {
    return makeBindingTarget { $0.center = $1 }
  }

  /// Sets the transform of the view
  public var transform: BindingTarget<CGAffineTransform> {
    return makeBindingTarget { $0.transform = $1 }
  }

  /// Sets the directionalLayoutMargins of the view
  @available(iOS 11, *)
  public var directionalLayoutMargins: BindingTarget<NSDirectionalEdgeInsets> {
    return makeBindingTarget { $0.directionalLayoutMargins = $1 }
  }

  /// Sets the layoutMargins of the view
  public var layoutMargins: BindingTarget<UIEdgeInsets> {
    return makeBindingTarget { $0.layoutMargins = $1 }
  }

  /// Sets the preservesSuperviewLayoutMargins of the view
  public var preservesSuperviewLayoutMargins: BindingTarget<Bool> {
    return makeBindingTarget { $0.preservesSuperviewLayoutMargins = $1 }
  }

  /// Sets the insetsLayoutMarginsFromSafeArea of the view
  @available(iOS 11, *)
  public var insetsLayoutMarginsFromSafeArea: BindingTarget<Bool> {
    return makeBindingTarget { $0.insetsLayoutMarginsFromSafeArea = $1 }
  }

  /// Sets the contentMode of the view
  public var contentMode: BindingTarget<UIViewContentMode> {
    return makeBindingTarget { $0.contentMode = $1 }
  }

  /// Sets the autoresizesSubviews of the view
  public var autoresizesSubviews: BindingTarget<Bool> {
    return makeBindingTarget { $0.autoresizesSubviews = $1 }
  }

  /// Sets the autoresizingMask of the view
  public var autoresizingMask: BindingTarget<UIViewAutoresizing> {
    return makeBindingTarget { $0.autoresizingMask = $1 }
  }

  /// Sets the translatesAutoresizingMaskIntoConstraints of the view
  public var translatesAutoresizingMaskIntoConstraints: BindingTarget<Bool> {
    return makeBindingTarget { $0.translatesAutoresizingMaskIntoConstraints = $1 }
  }

  /// Sets the semanticContentAttribute of the view
  @available(iOS 9, *)
  public var semanticContentAttribute: BindingTarget<UISemanticContentAttribute> {
    return makeBindingTarget { $0.semanticContentAttribute = $1 }
  }

  /// Sets the interactions of the view
  @available(iOS 11, *)
  public var interactions: BindingTarget<[UIInteraction]> {
    return makeBindingTarget { $0.interactions = $1 }
  }

  /// Sets the contentScaleFactor of the view
  public var contentScaleFactor: BindingTarget<CGFloat> {
    return makeBindingTarget { $0.contentScaleFactor = $1 }
  }

  /// Sets the gestureRecognizers of the view
  public var gestureRecognizers: BindingTarget<[UIGestureRecognizer]?> {
    return makeBindingTarget { $0.gestureRecognizers = $1 }
  }

  /// Sets the motionEffects of the view
  public var motionEffects: BindingTarget<[UIMotionEffect]> {
    return makeBindingTarget { $0.motionEffects = $1 }
  }

  /// Sets the restorationIdentifier of the view
  public var restorationIdentifier: BindingTarget<String?> {
    return makeBindingTarget { $0.restorationIdentifier = $1 }
  }

  /// Sets the tag of the view
  public var tag: BindingTarget<Int> {
    return makeBindingTarget { $0.tag = $1 }
  }

  /// Sets the accessibilityIgnoresInvertColors of the view
  @available(iOS 11, *)
  public var accessibilityIgnoresInvertColors: BindingTarget<Bool> {
    return makeBindingTarget { $0.accessibilityIgnoresInvertColors = $1 }
  }

}
