//
//  UIView.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit

extension UIControl {
    /// Creates a producer for the sender whenever a specified control event is triggered.
    public func rex_controlEvents(events: UIControlEvents) -> SignalProducer<UIControl?, NoError> {
        return rac_signalForControlEvents(events)
            .toSignalProducer()
            .map { $0 as? UIControl }
            .flatMapError { _ in SignalProducer(value: nil) }
    }

    /// Wraps a control's `enabled` state in a bindable property.
    public var rex_enabled: MutableProperty<Bool> {
        return rex_valueProperty(&enabled, { [weak self] in self?.enabled ?? true }, { [weak self] in self?.enabled = $0 })
    }
}

private var enabled: UInt8 = 0
