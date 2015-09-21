//
//  Property.swift
//  Rex
//
//  Created by Neil Pankey on 5/29/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

/// A property that tracks a signals most recent value.
public struct SignalProperty<T>: PropertyType {
    private let property: MutableProperty<T>

    /// Current value of the property.
    public var value: T {
        return property.value
    }

    /// Sends the current `value` and any changes.
    public var producer: SignalProducer<T, NoError> {
        return property.producer
    }

    /// Creates a new property bound to `signal`.
    public init(_ value: T, _ signal: Signal<T, NoError>) {
        property = MutableProperty(value)
        property <~ signal
    }

    /// Creates a new property bound to `producer`.
    public init(_ value: T, _ producer: SignalProducer<T, NoError>) {
        property = MutableProperty(value)
        property <~ producer
    }
}

extension Signal where E: NoError {
    /// Creates a new property bound to `self` starting with `initialValue`.
    public func toProperty(initialValue: T) -> PropertyOf<T> {
        return PropertyOf(SignalProperty(initialValue, ignoreError()))
    }
}

extension SignalProducer where E: NoError {
    /// Creates a new property bound to `producer` starting with `initialValue`.
    public func toProperty(initialValue: T) -> PropertyOf<T> {
        return PropertyOf(SignalProperty(initialValue, ignoreError()))
    }
}
