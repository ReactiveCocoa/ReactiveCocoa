import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceObject {
	/// Sets the alpha value of the object.
	public var alpha: BindingTarget<CGFloat> {
		return makeBindingTarget { $0.setAlpha($1) }
	}
	
	/// Sets whether the object is hidden.
	public var isHidden: BindingTarget<Bool> {
		return makeBindingTarget { $0.setHidden($1) }
	}
}
