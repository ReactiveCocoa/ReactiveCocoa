//
//  Predicate.swift
//  Rex
//
//  Created by Neil Pankey on 10/17/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension PropertyType where Value == Bool {
    public func and<P: PropertyType where P.Value == Bool>(other: P) -> AndProperty {
        return AndProperty(terms: [AnyProperty(self), AnyProperty(other)])
    }

    public func and(other: AnyProperty<Bool>) -> AndProperty {
        return AndProperty(terms: [AnyProperty(self), other])
    }

    public func or<P: PropertyType where P.Value == Bool>(other: P) -> OrProperty {
        return OrProperty(terms: [AnyProperty(self), AnyProperty(other)])
    }

    public func or(other: AnyProperty<Bool>) -> OrProperty {
        return OrProperty(terms: [AnyProperty(self), other])
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

    public init(terms: [AnyProperty<Bool>]) {
        self.terms = terms
    }

    public func and<P : PropertyType where P.Value == Bool>(other: P) -> AndProperty {
        return AndProperty(terms: terms + [AnyProperty(other)])
    }

    public func and(other: AnyProperty<Bool>) -> AndProperty {
        return AndProperty(terms: terms + [other])
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

    public init(terms: [AnyProperty<Bool>]) {
        self.terms = terms
    }

    public func or<P : PropertyType where P.Value == Bool>(other: P) -> OrProperty {
        return OrProperty(terms: terms + [AnyProperty(other)])
    }

    public func or(other: AnyProperty<Bool>) -> OrProperty {
        return OrProperty(terms: terms + [other])
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
