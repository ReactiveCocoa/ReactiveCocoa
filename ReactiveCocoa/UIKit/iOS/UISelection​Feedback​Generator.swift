import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UISelectionFeedbackGenerator {
	/// Triggers the feedback.
	public var selectionChanged: BindingTarget<()> {
		return makeBindingTarget { generator, _ in
			generator.selectionChanged()
		}
	}
}
