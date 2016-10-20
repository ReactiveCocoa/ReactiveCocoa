import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UIDatePicker {
	/// Sets the date of the date picker.
	public var date: BindingTarget<Date> {
		return makeBindingTarget { $0.date = $1 }
	}

	/// A signal of dates emitted by the date picker.
	public var dates: Signal<Date, NoError> {
		return trigger(for: .valueChanged)
			.map { [unowned base = self.base] in base.date }
	}
}
