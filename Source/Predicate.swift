//
//  Predicate.swift
//  Rex
//
//  Created by Neil Pankey on 10/17/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

public protocol PredicateType: PropertyType {
    typealias Value = Bool
}

public struct AndProperty: PredicateType {
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

public struct OrProperty: PredicateType {
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

public struct NotProperty: PredicateType {
    private let property: PropertyOf<Bool>
    
    public var value: Bool {
        return !property.value
    }

    public var producer: SignalProducer<Bool, NoError> {
        return property.producer.map { !$0 }
    }

    public init<P: PropertyType where P.Value == Bool>(property: P) {
        self.property = PropertyOf(property)
    }
}
