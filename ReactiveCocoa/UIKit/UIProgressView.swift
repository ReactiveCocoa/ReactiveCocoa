import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UIProgressView {
	/// Sets the relative progress to be reflected by the progress view.
	public var progress: BindingTarget<Float> {
		return makeBindingTarget { $0.progress = $1 }
	}
}

extension UIProgressView {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UIProgressView,
		source: Source
	) -> Disposable? where Source.Value == Float, Source.Error == NoError {
		return target.reactive.progress <~ source
	}
}
