import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceSeparator {
	/// Sets the color of the separator.
	public var color: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setColor($1) }
	}
}
