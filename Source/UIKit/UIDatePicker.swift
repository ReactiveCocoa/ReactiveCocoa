//
//  UIDatePicker.swift
//  Rex
//
//  Created by Guido Marucci Blas on 3/25/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIDatePicker {

    // Wraps a datePicker's `date` value in a bindable property.
    public var rex_date: MutableProperty<NSDate> {
        return UIControl.rex_value(self, getter: { $0.date }, setter: { $0.date = $1 })
    }
}
