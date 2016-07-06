//
//  UITextField.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UITextField {
    
    /// Wraps a textField's `text` value in a bindable property.
    public var rex_text: MutableProperty<String?> {
        let getter: UITextField -> String? = { $0.text }
        let setter: (UITextField, String?) -> () = { $0.text = $1 }
#if os(iOS)
        return UIControl.rex_value(self, getter: getter, setter: setter)
#else
        return associatedProperty(self, key: &textKey, initial: getter, setter: setter) { property in
            property <~
                NSNotificationCenter.defaultCenter()
                    .rac_notifications(UITextFieldTextDidChangeNotification, object: self)
                    .filterMap  { ($0.object as? UITextField)?.text }
            }
#endif
    }

}

private var textKey: UInt8 = 0
