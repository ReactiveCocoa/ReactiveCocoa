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
        let notificationCenter = NSNotificationCenter.defaultCenter()
        let notificationsProducer = notificationCenter.rac_notifications(name: NSControlTextDidChangeNotification, object: self)
        return notificationsProducer
            |> filter { notification in (notification.object as? NSTextField) == self }
            |> map { notification in (notification.object as! NSTextField).stringValue }
    }
}