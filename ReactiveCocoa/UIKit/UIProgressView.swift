import ReactiveSwift
import UIKit

extension Reactive where Base: UIProgressView {
	/// Sets the reative progress to be reflected by the progress view.
	public var progress: BindingTarget<Float> {
		return makeBindingTarget { $0.progress = $1 }
	}
}
