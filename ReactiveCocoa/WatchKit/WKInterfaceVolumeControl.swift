import ReactiveSwift
import WatchKit

@available(watchOSApplicationExtension 5.0, *)
extension Reactive where Base: WKInterfaceVolumeControl {
	/// Sets the tint color of the volume control.
	public var tintColor: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setTintColor($1) }
	}
}
