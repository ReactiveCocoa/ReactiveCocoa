//
//  UIView.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import UIKit
import enum Result.NoError

extension UIControl {
#if os(iOS)
    /// Creates a producer for the sender whenever a specified control event is triggered.
    @warn_unused_result(message="Did you forget to use the property?")
    public func rex_controlEvents(events: UIControlEvents) -> SignalProducer<UIControl?, NoError> {
        return rac_signalForControlEvents(events)
            .toSignalProducer()
            .map { $0 as? UIControl }
            .flatMapError { _ in SignalProducer(value: nil) }
    }
#endif

    /// Wraps a control's `enabled` state in a bindable property.
    public var rex_enabled: MutableProperty<Bool> {
        return associatedProperty(self, key: &enabledKey, initial: { $0.enabled }, setter: { $0.enabled = $1 })
    }
    
    /// Wraps a control's `selected` state in a bindable property.
    public var rex_selected: MutableProperty<Bool> {
        return associatedProperty(self, key: &selectedKey, initial: { $0.selected }, setter: { $0.selected = $1 })
    }
    
    /// Wraps a control's `highlighted` state in a bindable property.
    public var rex_highlighted: MutableProperty<Bool> {
        return associatedProperty(self, key: &highlightedKey, initial: { $0.highlighted }, setter: { $0.highlighted = $1 })
    }
}

private var enabledKey: UInt8 = 0
private var selectedKey: UInt8 = 0
private var highlightedKey: UInt8 = 0
