import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceDate {
	/// Sets the color of the text of the date.
	public var textColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setTextColor($1) }
	}
}
