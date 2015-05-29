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
