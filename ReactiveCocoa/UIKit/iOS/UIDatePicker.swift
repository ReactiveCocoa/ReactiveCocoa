import ReactiveSwift
import enum Result.NoError
import UIKit

extension UIDatePicker: ReactiveControlConfigurable {
	public static var defaultControlEvents: UIControlEvents {
		return .valueChanged
	}
}

extension Reactive where Base: UIDatePicker {
	/// Sets the date of the date picker.
	public var date: ValueBindable<Base, Date> {
		return self[\.date]
	}

	/// A signal of dates emitted by the date picker.
	public var dates: Signal<Date, NoError> {
		return map(\.date)
	}
}
