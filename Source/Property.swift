//
//  Property.swift
//  Rex
//
//  Created by Neil Pankey on 5/29/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

public struct SignalProperty<T>: PropertyType {
    private let property: MutableProperty<T>

    public var value: T {
        return property.value
    }

    public var producer: SignalProducer<T, NoError> {
        return property.producer
    }

    public init(_ value: T, _ signal: Signal<T, NoError>) {
        property = MutableProperty(value)
        property <~ signal
    }

    public init(_ value: T, _ producer: SignalProducer<T, NoError>) {
        property = MutableProperty(value)
        property <~ producer
    }
}

public func propertyOf<T>(initialValue: T)(signal: Signal<T, NoError>) -> PropertyOf<T> {
    return PropertyOf(SignalProperty(initialValue, signal))
}

public func sinkProperty<S: SinkType>(initialValue: S)(signal: Signal<S.Element, NoError>) -> PropertyOf<S> {
    return signal
        |> scan(initialValue) { (var value, change) in
            value.put(change)
            return value
        }
        |> map { $0.0 }
        |> propertyOf(initialValue)
}
