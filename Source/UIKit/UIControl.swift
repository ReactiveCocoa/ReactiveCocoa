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
    public typealias InstanceType = UIControl

    /// Creates a producer for the sender whenever a specified control event is triggered.
    public func rex_controlEvents(events: UIControlEvents) -> SignalProducer<UIControl?, NoError> {
        return rac_signalForControlEvents(events)
            .toSignalProducer()
            .map { $0 as? UIControl }
            .flatMapError { _ in SignalProducer(value: nil) }
    }

    /// Wraps a control's `enabled` state in a bindable property.
    public var rex_enabled: MutableProperty<Bool> {
        return rex_valueProperty(&enabledKey, { $0.enabled }, { $0.enabled = $1 })
    }
    
    /// Wraps a control's `selected` state in a bindable property.
    public var rex_selected: MutableProperty<Bool> {
        return rex_valueProperty(&selectedKey, { $0.selected }, { $0.selected = $1 })
    }
    
    /// Wraps a control's `highlighted` state in a bindable property.
    public var rex_highlighted: MutableProperty<Bool> {
        return rex_valueProperty(&highlightedKey, { $0.highlighted }, { $0.highlighted = $1 })
    }
}

private var enabledKey: UInt8 = 0
private var selectedKey: UInt8 = 0
private var highlightedKey: UInt8 = 0
