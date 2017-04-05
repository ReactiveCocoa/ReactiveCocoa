import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UINotificationFeedbackGenerator {
	/// Prepares the feedback generator.
	public var notificationOccurred: BindingTarget<UINotificationFeedbackType> {
		return makeBindingTarget { $0.notificationOccurred($1) }
	}
}
