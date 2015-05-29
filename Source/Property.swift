//
//  Property.swift
//  Rex
//
//  Created by Neil Pankey on 5/29/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

public final class SignalProperty<T>: PropertyType {
    private let property: MutableProperty<T>
    private let disposable: Disposable?

    public var value: T {
        return property.value
    }

    public var producer: SignalProducer<T, NoError> {
        return property.producer
    }

    public init(_ value: T, _ producer: SignalProducer<T, NoError>) {
        property = MutableProperty(value)
        disposable = (property <~ producer)
    }

    public init(_ value: T, _ signal: Signal<T, NoError>) {
        property = MutableProperty(value)
        disposable = (property <~ signal)
    }

    deinit {
        disposable?.dispose()
    }
}
