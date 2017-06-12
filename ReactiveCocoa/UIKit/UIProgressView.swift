import ReactiveSwift
import UIKit

extension Reactive where Base: UIProgressView {
	/// Sets the relative progress to be reflected by the progress view.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.progress)` instead.")
	public var progress: BindingTarget<Float> {
		return makeBindingTarget { $0.progress = $1 }
	}
}
