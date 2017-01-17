import UIKit
import ReactiveSwift
import enum Result.NoError

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

	/// A signal of float values emitted by the slider while being dragged by
	/// the user.
	///
	/// - note: If slider's `isContinuous` property is `false` then values are
	///         sent only when user releases the slider.
	public var values: Signal<Float, NoError> {
		return controlEvents(.valueChanged).map { $0.value }
	}
}

extension UISlider {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UISlider,
		source: Source
	) -> Disposable? where Source.Value == Float, Source.Error == NoError {
		return target.reactive.value <~ source
	}
}

extension UISlider: BindingSourceProtocol {
	public func observe(_ observer: Observer<Float, NoError>, during lifetime: Lifetime) -> Disposable? {
		return reactive.values.take(during: lifetime).observe(observer)
	}
}
