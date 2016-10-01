//
//  UISegmentedControl.swift
//  Rex
//
//  Created by Markus Chmelar on 07/06/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactivity where Reactant: UISegmentedControl {
	/// Wraps a segmentedControls `selectedSegmentIndex` state in a bindable property.
	public var selectedSegmentIndex: MutableProperty<Int> {
		let property = associatedProperty(reactant,
		                                  key: &selectedSegmentIndexKey,
		                                  initial: { $0.selectedSegmentIndex },
		                                  setter: { $0.selectedSegmentIndex = $1 })

		property <~ trigger(for: .valueChanged).map { $0.selectedSegmentIndex }
		return property
	}
}

private var selectedSegmentIndexKey: UInt8 = 0
