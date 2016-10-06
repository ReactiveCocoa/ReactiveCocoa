//
//  UISegmentedControl.swift
//  Rex
//
//  Created by Markus Chmelar on 07/06/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import enum Result.NoError
import UIKit

extension Reactive where Base: UISegmentedControl {
	/// Wraps a segmentedControls `selectedSegmentIndex` state in a bindable property.
	public var selectedSegmentIndex: BindingTarget<Int> {
		return makeBindingTarget { $0.selectedSegmentIndex = $1 }
	}

	public var selectedSegmentIndexes: Signal<Int, NoError> {
		return trigger(for: .valueChanged).map { [unowned base] in base.selectedSegmentIndex }
	}
}
