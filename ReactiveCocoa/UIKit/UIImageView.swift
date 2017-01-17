import ReactiveSwift
import enum Result.NoError
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

extension UIImageView {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UIImageView,
		source: Source
	) -> Disposable? where Source.Value == UIImage, Source.Error == NoError {
		return target.reactive.image <~ source
	}

	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UIImageView,
		source: Source
	) -> Disposable? where Source.Value == UIImage?, Source.Error == NoError {
		return target.reactive.image <~ source
	}
}
