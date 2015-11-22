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
        return rex_valueProperty(&enabledKey, { [weak self] in self?.enabled ?? true }, { [weak self] in self?.enabled = $0 })
    }
    
    /// Wraps a control's `selected` state in a bindable property.
    public var rex_selected: MutableProperty<Bool> {
        return rex_valueProperty(&selectedKey, { [weak self] in self?.selected ?? false }, { [weak self] in self?.selected = $0 })
    }
    
    /// Wraps a control's `highlighted` state in a bindable property.
    public var rex_highlighted: MutableProperty<Bool> {
        return rex_valueProperty(&highlightedKey, { [weak self] in self?.highlighted ?? false }, { [weak self] in self?.highlighted = $0 })
    }
}

private var enabledKey: UInt8 = 0
private var selectedKey: UInt8 = 0
private var highlightedKey: UInt8 = 0
