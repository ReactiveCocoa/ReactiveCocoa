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
		return trigger(for: .valueChanged)
			.map { [unowned base = self.base] in base.selectedSegmentIndex }
	}
}
