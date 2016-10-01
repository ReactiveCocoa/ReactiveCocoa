//
//  UITextField.swift
//  Rex
//
//  Created by Rui Peres on 17/01/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import UIKit

extension Reactivity where Reactant: UITextField {
	/// Wraps a textField's `text` value in a bindable property.
	public var text: MutableProperty<String?> {
		let getter: (UITextField) -> String? = { $0.text }
		let setter: (UITextField, String?) -> () = { $0.text = $1 }
		#if os(iOS)
			return value(getter: getter, setter: setter)
		#else
			return associatedProperty(reactant, key: &textKey, initial: getter, setter: setter) { property in
				property <~
					NotificationCenter.default
						.rac_notifications(forName: .UITextFieldTextDidChange, object: reactant)
						.map { ($0.object as! UITextField).text }
			}
		#endif
	}

}

private var textKey: UInt8 = 0
