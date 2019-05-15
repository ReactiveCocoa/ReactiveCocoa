import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceTimer {
	/// Sets the start date of the timer.
	public var date: BindingTarget<Date> {
		return makeBindingTarget { $0.setDate($1) }
	}
	
	/// Sets the color of the text of the timer.
	public var textColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setTextColor($1) }
	}
}
