import UIKit
import ReactiveSwift

extension Reactive where Base: UIStepper {

	/// Sets the stepper's value.
	public var value: BindingTarget<Double> {
		return makeBindingTarget { $0.value = $1 }
	}
}
