import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UISegmentedControl {
	/// Changes the selected segment of the segmented control.
	public var selectedSegmentIndex: BindingTarget<Int> {
		return makeBindingTarget { $0.selectedSegmentIndex = $1 }
	}

	/// A signal of indexes of selections emitted by the segmented control.
	public var selectedSegmentIndexes: Signal<Int, NoError> {
		return controlEvents(.valueChanged).map { $0.selectedSegmentIndex }
	}
}

extension UISegmentedControl {
	@discardableResult
	public static func <~ <Source: BindingSourceProtocol>(
		target: UISegmentedControl,
		source: Source
	) -> Disposable? where Source.Value == Int, Source.Error == NoError {
		return target.reactive.selectedSegmentIndex <~ source
	}
}

extension UISegmentedControl: BindingSourceProtocol {
	public func observe(_ observer: Observer<Int, NoError>, during lifetime: Lifetime) -> Disposable? {
		return reactive.selectedSegmentIndexes.take(during: lifetime).observe(observer)
	}
}
