import ReactiveSwift
import WatchKit
import HealthKit

@available(watchOSApplicationExtension 2.2, *)
extension Reactive where Base: WKInterfaceActivityRing {
	/// Sets the summary of the activity ring.
	///
	/// - Parameter animated: Whether updates are animated.
	public func activitySummary(animated: Bool) -> BindingTarget<HKActivitySummary?> {
		return makeBindingTarget { $0.setActivitySummary($1, animated: animated) }
	}
}
