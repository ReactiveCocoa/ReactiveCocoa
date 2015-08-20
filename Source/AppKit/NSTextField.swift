//
//  NSTextField.swift
//  Rex
//
//  Created by Yury Lapitsky on 7/8/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Foundation
import ReactiveCocoa
import AppKit

extension NSTextField {
    /// only changes from UI will be produced here
    public var rex_textSignal: SignalProducer<String, NoError> {
        return NSNotificationCenter.defaultCenter()
            .rac_notifications(NSControlTextDidChangeNotification, object: self)
            .map { notification in
                (notification.object as! NSTextField).stringValue
            }
    }
}
