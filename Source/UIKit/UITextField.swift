//
//  UITextField.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import enum Result.NoError

extension UITextField {
    
    /// Sends the field's string value whenever it changes.
    public var rex_textSignal: SignalProducer<String, NoError> {
        return NSNotificationCenter.defaultCenter()
            .rac_notifications(UITextFieldTextDidChangeNotification, object: self)
            .filterMap  { ($0.object as? UITextField)?.text }
    }
}