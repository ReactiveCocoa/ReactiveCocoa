import ReactiveSwift
import WatchKit

extension Reactive where Base: WKInterfaceSlider {
	/// Sets the value of the slider.
	public var value: BindingTarget<Float> {
		return makeBindingTarget { $0.setValue($1) }
	}
	
	/// Sets the number of steps of the slider.
	public var numberOfSteps: BindingTarget<Int> {
		return makeBindingTarget { $0.setNumberOfSteps($1) }
	}
	
	/// Sets the color of the slider.
	public var color: BindingTarget<UIColor?> {
		return makeBindingTarget { $0.setColor($1) }
	}
	
	/// Sets whether the slider is enabled.
	public var isEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.setEnabled($1) }
	}
}
