import UIKit
import ReactiveSwift

extension Reactive where Base: UISlider {

	/// Sets slider's value.
	public var value: BindingTarget<Float> {
		return makeBindingTarget { $0.value = $1 }
	}

	/// Sets slider's minimum value.
	public var minimumValue: BindingTarget<Float> {
		return makeBindingTarget { $0.minimumValue = $1 }
	}

	/// Sets slider's maximum value.
	public var maximumValue: BindingTarget<Float> {
		return makeBindingTarget { $0.maximumValue = $1 }
	}

}
