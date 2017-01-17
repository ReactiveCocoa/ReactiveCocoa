import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UIActivityIndicatorView {
	/// Sets whether the activity indicator should be animating.
	public var isAnimating: BindingTarget<Bool> {
		return makeBindingTarget { $1 ? $0.startAnimating() : $0.stopAnimating() }
	}
}

extension UIActivityIndicatorView {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UIActivityIndicatorView,
		source: Source
	) -> Disposable? where Source.Value == Bool, Source.Error == NoError {
		return target.reactive.isAnimating <~ source
	}
}
