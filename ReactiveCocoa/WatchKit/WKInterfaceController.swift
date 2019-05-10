import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceController {
	/// Sets the title of the controller.
	public var title: BindingTarget<String?> {
		return makeBindingTarget { $0.setTitle($1) }
	}
}
