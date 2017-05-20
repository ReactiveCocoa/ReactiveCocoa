import UIKit
import ReactiveSwift
import enum Result.NoError

extension UIStepper: ReactiveControlConfigurable {
	public static var defaultControlEvents: UIControlEvents {
		return .valueChanged
	}
}

extension Reactive where Base: UIStepper {

	/// Sets the stepper's value.
	public var value: ValueBindable<Base, Double> {
        return self[\.value]
	}

	/// Sets stepper's minimum value.
	public var minimumValue: BindingTarget<Double> {
		return makeBindingTarget { $0.minimumValue = $1 }
	}

	/// Sets stepper's maximum value.
	public var maximumValue: BindingTarget<Double> {
		return makeBindingTarget { $0.maximumValue = $1 }
	}

	/// A signal of double values emitted by the stepper upon each user's
	/// interaction.
	public var values: Signal<Double, NoError> {
		return map(\.value)
	}
}
