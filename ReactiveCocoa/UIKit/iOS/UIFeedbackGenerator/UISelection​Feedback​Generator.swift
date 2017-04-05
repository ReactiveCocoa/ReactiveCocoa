import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UISelectionFeedbackGenerator {
	/// Prepares the feedback generator.
	public var selectionChanged: BindingTarget<Void> {
		return makeBindingTarget { generator, _ in
			generator.selectionChanged()
		}
	}
}
