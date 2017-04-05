import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UIFeedbackGenerator {
	/// Prepares the feedback generator.
	public var prepare: BindingTarget<()> {
		return makeBindingTarget { generator, _ in
			generator.prepare()
		}
	}
}
