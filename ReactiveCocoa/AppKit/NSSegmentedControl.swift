import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSSegmentedControl {
	/// Changes the selected segment of the segmented control.
	public var selectedSegment: BindingTarget<Int> {
		return makeBindingTarget { $0.selectedSegment = $1 }
	}

	/// A signal of indexes of selections emitted by the segmented control.
	public var selectedSegments: Signal<Int, NoError> {
		return trigger.map { [unowned base = self.base] in base.selectedSegment }
	}

	/// The below are provided for cross-platform compatibility

	/// Changes the selected segment of the segmented control.
	public var selectedSegmentIndex: BindingTarget<Int> { return selectedSegment }
	/// A signal of indexes of selections emitted by the segmented control.
	public var selectedSegmentIndexes: Signal<Int, NoError> { return selectedSegments }
}
