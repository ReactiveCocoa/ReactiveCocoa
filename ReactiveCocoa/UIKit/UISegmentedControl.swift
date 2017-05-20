import ReactiveSwift
import enum Result.NoError
import UIKit

extension UISegmentedControl: ReactiveControlConfigurable {
	public static var defaultControlEvents: UIControlEvents {
		return [.valueChanged]
	}
}

extension Reactive where Base: UISegmentedControl {
	/// Changes the selected segment of the segmented control.
	public var selectedSegmentIndex: ValueBindable<Base, Int> {
		return self[\.selectedSegmentIndex]
	}

	/// A signal of indexes of selections emitted by the segmented control.
	public var selectedSegmentIndexes: Signal<Int, NoError> {
		return map(\.selectedSegmentIndex)
	}
}
