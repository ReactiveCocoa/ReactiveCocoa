//
//  Predicate.swift
//  Rex
//
//  Created by Neil Pankey on 10/17/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension PropertyType where Value == Bool {
    public func and(other: Self) -> AndProperty {
        return AndProperty(lhs: self, rhs: other)
    }

    public func or(other: Self) -> OrProperty {
        return OrProperty(lhs: self, rhs: other)
    }

    public func not() -> NotProperty {
        return NotProperty(property: self)
    }
}

public protocol CompoundPropertyType: PropertyType {
    var terms: [AnyProperty<Value>] { get }
}

public struct AndProperty: CompoundPropertyType {
    public let terms: [AnyProperty<Bool>]

    public var value: Bool {
        return terms.reduce(true) { $0 && $1.value }
    }

    public var producer: SignalProducer<Bool, NoError> {
        let producers = terms.map { $0.producer }
        return combineLatest(producers).map { values in
            return values.reduce(true) { $0 && $1 }
        }
    }

    public init<L: PropertyType, R: PropertyType where L.Value == Bool, R.Value == Bool>(lhs: L, rhs: R) {
        terms = [AnyProperty(lhs), AnyProperty(rhs)]
    }
}

public struct OrProperty: CompoundPropertyType {
    public let terms: [AnyProperty<Bool>]
    
    public var value: Bool {
        return terms.reduce(false) { $0 || $1.value }
    }
    
    public var producer: SignalProducer<Bool, NoError> {
        let producers = terms.map { $0.producer }
        return combineLatest(producers).map { values in
            return values.reduce(false) { $0 || $1 }
        }
    }
    
    public init<L: PropertyType, R: PropertyType where L.Value == Bool, R.Value == Bool>(lhs: L, rhs: R) {
        terms = [AnyProperty(lhs), AnyProperty(rhs)]
    }
}

public struct NotProperty: PropertyType {
    private let source: AnyProperty<Bool>
    
    public var value: Bool {
        return !source.value
    }

    public var producer: SignalProducer<Bool, NoError> {
        return source.producer.map { !$0 }
    }

    public init<P: PropertyType where P.Value == Bool>(property: P) {
        source = AnyProperty(property)
    }
}
