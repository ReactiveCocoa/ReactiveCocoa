import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UINotificationFeedbackGenerator {
	/// Triggers the feedback.
	public var notificationOccurred: BindingTarget<UINotificationFeedbackGenerator.FeedbackType> {
		return makeBindingTarget { $0.notificationOccurred($1) }
	}
}
