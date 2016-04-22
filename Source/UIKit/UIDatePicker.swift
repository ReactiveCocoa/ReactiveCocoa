//
//  UIDatePicker.swift
//  Rex
//
//  Created by Guido Marucci Blas on 3/25/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//
import UIKit
import ReactiveCocoa

extension UIDatePicker {
    
    public var rex_date: MutableProperty<NSDate> {
        let initial = { (picker: UIDatePicker) -> NSDate in
            picker.addTarget(self, action: #selector(UIDatePicker.rex_changedDate), forControlEvents: .ValueChanged)
            return picker.date
        }
        return associatedProperty(self, key: &dateKey, initial: initial) { $0.date = $1 }
    }
    
    @objc
    private func rex_changedDate() {
        rex_date.value = date
    }
    
}

private var dateKey: UInt8 = 0
