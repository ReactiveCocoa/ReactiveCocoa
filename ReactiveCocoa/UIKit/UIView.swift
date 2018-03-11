import ReactiveSwift
import UIKit


protocol ReactiveUIView {
	// Configuring a View's Visual Appearence
	var backgroundColor: BindingTarget<UIColor> { get }
	var isHidden: BindingTarget<Bool> { get }
	var alpha: BindingTarget<CGFloat> { get }
	var isOpaque: BindingTarget<Bool> { get }
	var tintColor: BindingTarget<UIColor> { get }
	var tintAdjustmentMode: BindingTarget<UIViewTintAdjustmentMode> { get }
	var clipsToBounds: BindingTarget<Bool> { get }
	var clearsContextBeforeDrawing: BindingTarget<Bool> { get }
	var mask: BindingTarget<UIView?> { get }
	// Configuring the Event-Related Behaviour
	var isUserInteractionEnabled: BindingTarget<Bool> { get }
	var isMultipleTouchEnabled: BindingTarget<Bool> { get }
	var isExclusiveTouch: BindingTarget<Bool> { get }
	// Configuring the Bounds and Frame Rectangles
	var frame: BindingTarget<CGRect> { get }
	var bounds: BindingTarget<CGRect> { get }
	var center: BindingTarget<CGPoint> { get }
	var transform: BindingTarget<CGAffineTransform> { get }
	// Configuring Content Margins
	@available(iOS 11, *)
	var directionalLayoutMargins: BindingTarget<NSDirectionalEdgeInsets> { get }
	var layoutMargins: BindingTarget<UIEdgeInsets> { get }
	var preservesSuperviewLayoutMargins: BindingTarget<Bool> { get }
	// Getting the Save Area
	@available(iOS 11, *)
	var insetsLayoutMarginsFromSafeArea: BindingTarget<Bool> { get }
	// Configuring the Resizing Behavior
	var contentMode: BindingTarget<UIViewContentMode> { get }
	var autoresizesSubviews: BindingTarget<Bool> { get }
	var autoresizingMask: BindingTarget<UIViewAutoresizing> { get }
	// Laying out Subviews
	var translatesAutoresizingMaskIntoConstraints: BindingTarget<Bool> { get }
	// Managing the User Interface Direction
	@available(iOS 9, *)
	var semanticContentAttribute: BindingTarget<UISemanticContentAttribute> { get }
	// Supporting Drag and Drop Interactions
	@available(iOS 11, *)
	var interactions: BindingTarget<[UIInteraction]> { get }
	// Drawing and Updating the View
	var contentScaleFactor: BindingTarget<CGFloat> { get }
	// Managing Gesture Recognizers
	var gestureRecognizers: BindingTarget<[UIGestureRecognizer]?> { get }
	// Using Motion Effects
	var motionEffects: BindingTarget<[UIMotionEffect]> { get }
	// Preserving and Restoring State
	var restorationIdentifier: BindingTarget<String?> { get }
	// Identifying the View at Runtime
	var tag: BindingTarget<Int> { get }
	// Modyfing the Accessibility Behavior
	@available(iOS 11, *)
	var accessibilityIgnoresInvertColors: BindingTarget<Bool> { get }
}

