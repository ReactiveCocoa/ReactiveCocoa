import ReactiveSwift
import UIKit

@available(iOS 10.0, *)
extension Reactive where Base: UINotificationFeedbackGenerator {
	/// Triggers the feedback.
    
    #if swift(>=4.2)
        public typealias UINotificationFeedbackType = UINotificationFeedbackGenerator.FeedbackType
    #endif
    
    public var notificationOccurred: BindingTarget<UINotificationFeedbackType> {
		return makeBindingTarget { $0.notificationOccurred($1) }
	}
}
