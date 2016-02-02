//
//  UITextField.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import Foundation
import ReactiveCocoa
import UIKit
import enum Result.NoError

extension UITextField {
    
    /// Sends the field's string value whenever it changes.
    public var rex_textSignal: SignalProducer<String, NoError> {
        return NSNotificationCenter.defaultCenter()
            .rac_notifications(UITextFieldTextDidChangeNotification, object: self)
            .filterMap { notification in
                guard let textField = notification.object as? UITextField else { return nil}
                return textField.text
        }
    }
}
