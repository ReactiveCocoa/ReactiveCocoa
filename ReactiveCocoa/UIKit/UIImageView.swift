import ReactiveSwift
import UIKit

protocol ReactiveUIImageView {
	var image: BindingTarget<UIImage?> { get }
	var highlightedImage: BindingTarget<UIImage?> { get }
}


