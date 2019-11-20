#if canImport(UIKit) && !os(watchOS)
import ReactiveSwift
import UIKit

extension Reactive where Base: UIImageView {
	/// Sets the image of the image view.
	public var image: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.image = $1 }
	}

	/// Sets the image of the image view for its highlighted state.
	public var highlightedImage: BindingTarget<UIImage?> {
		return makeBindingTarget { $0.highlightedImage = $1 }
	}
}
#endif
