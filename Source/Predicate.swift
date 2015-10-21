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

public struct AndProperty: PropertyType {
    private let left: PropertyOf<Bool>
    private let right: PropertyOf<Bool>
    
    public var value: Bool {
        return left.value && right.value
    }

    public var producer: SignalProducer<Bool, NoError> {
        return combineLatest(left.producer, right.producer).map { $0 && $1 }
    }
    
    public init<L: PropertyType, R: PropertyType where L.Value == Bool, R.Value == Bool>(lhs: L, rhs: R) {
        left = PropertyOf(lhs)
        right = PropertyOf(rhs)
    }
}

public struct OrProperty: PropertyType {
    private let left: PropertyOf<Bool>
    private let right: PropertyOf<Bool>
    
    public var value: Bool {
        return left.value || right.value
    }
    
    public var producer: SignalProducer<Bool, NoError> {
        return combineLatest(left.producer, right.producer).map { $0 || $1 }
    }

    public init<L: PropertyType, R: PropertyType where L.Value == Bool, R.Value == Bool>(lhs: L, rhs: R) {
        left = PropertyOf(lhs)
        right = PropertyOf(rhs)
    }
}

public struct NotProperty: PropertyType {
    private let source: PropertyOf<Bool>
    
    public var value: Bool {
        return !source.value
    }

    public var producer: SignalProducer<Bool, NoError> {
        return source.producer.map { !$0 }
    }

    public init<P: PropertyType where P.Value == Bool>(property: P) {
        source = PropertyOf(property)
    }
}
