//
//  Property.swift
//  Rex
//
//  Created by Neil Pankey on 10/17/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import enum Result.NoError

extension PropertyProtocol where Value == Bool {
    /// The conjunction of `self` and `other`.
    public func and<P: PropertyProtocol where P.Value == Bool>(_ other: P) -> AndProperty {
        return AndProperty(terms: [AnyProperty(self), AnyProperty(other)])
    }

    /// The conjunction of `self` and `other`.
    public func and(_ other: AnyProperty<Bool>) -> AndProperty {
        return AndProperty(terms: [AnyProperty(self), other])
    }

    /// The disjunction of `self` and `other`.
    public func or<P: PropertyProtocol where P.Value == Bool>(_ other: P) -> OrProperty {
        return OrProperty(terms: [AnyProperty(self), AnyProperty(other)])
    }

    /// The disjunction of `self` and `other`.
    public func or(_ other: AnyProperty<Bool>) -> OrProperty {
        return OrProperty(terms: [AnyProperty(self), other])
    }

    /// A negated property of `self`.
    public func not() -> NotProperty {
        return NotProperty(source: AnyProperty(self), invert: true)
    }
}

/// Specialized `PropertyType` for the conjuction of a set of boolean properties.
public struct AndProperty: PropertyProtocol {
    public let terms: [AnyProperty<Bool>]

    public var value: Bool {
        return terms.reduce(true) { $0 && $1.value }
    }

    public var producer: SignalProducer<Bool, NoError> {
        let producers = terms.map { $0.producer }
        return SignalProducer.combineLatest(producers).map { values in
            return values.reduce(true) { $0 && $1 }
        }
    }

    public var signal: Signal<Bool, NoError> {
        let signals = terms.map { $0.signal }
        return Signal.combineLatest(signals).map { values in
            return values.reduce(true) { $0 && $1 }
        }
    }

    /// Creates a new property with an additional conjunctive term.
    public func and<P : PropertyProtocol where P.Value == Bool>(_ other: P) -> AndProperty {
        return AndProperty(terms: terms + [AnyProperty(other)])
    }

    /// Creates a new property with an additional conjunctive term.
    public func and(_ other: AnyProperty<Bool>) -> AndProperty {
        return AndProperty(terms: terms + [other])
    }

    private init(terms: [AnyProperty<Bool>]) {
        self.terms = terms
    }
}

/// Specialized `PropertyType` for the disjunction of a set of boolean properties.
public struct OrProperty: PropertyProtocol {
    public let terms: [AnyProperty<Bool>]
    
    public var value: Bool {
        return terms.reduce(false) { $0 || $1.value }
    }
    
    public var producer: SignalProducer<Bool, NoError> {
        let producers = terms.map { $0.producer }
        return SignalProducer.combineLatest(producers).map { values in
            return values.reduce(false) { $0 || $1 }
        }
    }

    public var signal: Signal<Bool, NoError> {
        let signals = terms.map { $0.signal }
        return Signal.combineLatest(signals).map { values in
            return values.reduce(false) { $0 || $1 }
        }
    }

    /// Creates a new property with an additional disjunctive term.
    public func or<P : PropertyProtocol where P.Value == Bool>(_ other: P) -> OrProperty {
        return OrProperty(terms: terms + [AnyProperty(other)])
    }

    /// Creates a new property with an additional disjunctive term.
    public func or(_ other: AnyProperty<Bool>) -> OrProperty {
        return OrProperty(terms: terms + [other])
    }

    private init(terms: [AnyProperty<Bool>]) {
        self.terms = terms
    }
}

/// Specialized `PropertyType` for the negation of a boolean property.
public struct NotProperty: PropertyProtocol {
    private let source: AnyProperty<Bool>
    private let invert: Bool
    
    public var value: Bool {
        return source.value != invert
    }

    public var producer: SignalProducer<Bool, NoError> {
        return source.producer.map { $0 != self.invert }
    }

    public var signal: Signal<Bool, NoError> {
        return source.signal.map { $0 != self.invert }
    }

    /// A negated property of `self`.
    public func not() -> NotProperty {
        return NotProperty(source: source, invert: !invert)
    }

    private init(source: AnyProperty<Bool>, invert: Bool) {
        self.source = source
        self.invert = invert
    }
}
