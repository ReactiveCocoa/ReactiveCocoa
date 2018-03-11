import ReactiveSwift
import enum Result.NoError
import UIKit

protocol ReactiveUISegmentedControl {
	var selectedSegmentIndex: BindingTarget<Int> { get }
}

extension Reactive where Base: UISegmentedControl {
	/// A signal of indexes of selections emitted by the segmented control.
	public var selectedSegmentIndexes: Signal<Int, NoError> {
		return mapControlEvents(.valueChanged) { $0.selectedSegmentIndex }
	}
}
