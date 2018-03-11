import ReactiveSwift
import UIKit

protocol ReactiveUIProgressView {
	// Managing the Progress Bar
	var progress: BindingTarget<Float> { get}
	@available(iOS 9, *)
	var observedProgress: BindingTarget<Progress?> { get}
	// Configuring the Progress Bar
	var progressViewStyle: BindingTarget<UIProgressViewStyle> { get}
	var progressTintColor: BindingTarget<UIColor?> { get}
	var progressImage: BindingTarget<UIImage?> { get}
	var trackTintColor: BindingTarget<UIColor?> { get}
	var trackImage: BindingTarget<UIImage?> { get}
}
