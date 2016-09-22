//
//  UIDatePicker.swift
//  Rex
//
//  Created by Guido Marucci Blas on 3/25/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension UIDatePicker {
	// Wraps a datePicker's `date` value in a bindable property.
	public var rac_date: MutableProperty<Date> {
		return UIControl.rac_value(self, getter: { $0.date }, setter: { $0.date = $1 })
	}
}
