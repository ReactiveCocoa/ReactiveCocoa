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
		return controlEvents(.valueChanged).map { $0.date }
	}
}

extension UIDatePicker {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UIDatePicker,
		source: Source
	) -> Disposable? where Source.Value == Date, Source.Error == NoError {
		return target.reactive.date <~ source
	}
}

extension UIDatePicker: BindingSourceProtocol {
	public func observe(_ observer: Observer<Date, NoError>, during lifetime: Lifetime) -> Disposable? {
		return reactive.dates.take(during: lifetime).observe(observer)
	}
}

