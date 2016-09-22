//
//  UISegmentedControl.swift
//  Rex
//
//  Created by Markus Chmelar on 07/06/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension UISegmentedControl {
	/// Wraps a segmentedControls `selectedSegmentIndex` state in a bindable property.
	public var rex_selectedSegmentIndex: MutableProperty<Int> {
		let property = associatedProperty(self, key: &selectedSegmentIndexKey, initial: { $0.selectedSegmentIndex }, setter: { $0.selectedSegmentIndex = $1 })
		property <~ trigger(for: .valueChanged)
			.map { [unowned self] in self.selectedSegmentIndex }
		return property
	}
}

private var selectedSegmentIndexKey: UInt8 = 0
