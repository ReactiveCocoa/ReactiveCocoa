import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UIImpactFeedbackGenerator {
	/// Triggers the feedback.
	public var impactOccurred: BindingTarget<()> {
		return makeBindingTarget { generator, _ in
			generator.impactOccurred()
		}
	}
}
