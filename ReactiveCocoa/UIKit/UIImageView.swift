import ReactiveSwift
import UIKit

extension Reactive where Base: UIImageView {
	/// Sets the image of the image view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.image)` instead.")
	public var image: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.image = $1 }
	}

	/// Sets the image of the image view for its highlighted state.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.highlightedImage)` instead.")
	public var highlightedImage: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.highlightedImage = $1 }
	}
}
