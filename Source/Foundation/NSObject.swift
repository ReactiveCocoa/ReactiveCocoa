//
//  NSObject.swift
//  Rex
//
//  Created by Neil Pankey on 5/28/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Foundation
import ReactiveCocoa

extension NSObject {
    /// Creates a strongly-typed producer to monitor `keyPath` via KVO. The caller
    /// is responsible for ensuring that the associated value is castable to `T`.
    ///
    /// Swift classes deriving `NSObject` must declare properties as `dynamic` for
    /// them to work with KVO. However, this is not recommended practice.
    public func rex_producerForKeyPath<T>(keyPath: String) -> SignalProducer<T, NoError> {
        return self.rac_valuesForKeyPath(keyPath, observer: nil)
            .toSignalProducer()
            .map { $0 as! T }
            .flatMapError { error in
                // Errors aren't possible, but the compiler doesn't know that.
                assertionFailure("Unexpected error from KVO signal: \(error)")
                return .empty
            }
    }

    /// Attaches a `MutableProperty` relying on KVC for the initial value and subsequent
    /// updates. Note that `keyPath` is a `StaticString` because it's pointer value is used
    /// as key value when associating the property.
    ///
    /// This can be used as an alternative to `DynamicProperty` for creating strongly typed
    /// bindings on Cocoa objects.
    public func rex_stringProperty(keyPath: StaticString) -> MutableProperty<String> {
        return associatedProperty(self, keyPath: keyPath)
    }

    /// Attaches a `MutableProperty` relying on KVC for the initial value and subsequent
    /// updates. Note that `keyPath` is a `StaticString` because it's pointer value is used
    /// as key value when associating the property.
    ///
    /// This can be used as an alternative to `DynamicProperty` for creating strongly typed
    /// bindings on Cocoa objects.
    ///
    /// N.B. Ensure that `self` isn't strongly captured by `placeholder`, otherwise this will
    /// create a retain cycle causing `self` to never dealloc.
    public func rex_classProperty<T: AnyObject>(keyPath: StaticString, placeholder: () -> T) -> MutableProperty<T> {
        return associatedProperty(self, keyPath: keyPath, placeholder: placeholder)
    }

    /// Attaches a `MutableProperty` value under `key`. The property is initialized with
    /// the result of `initial`. Changes on the property's producer are monitored and
    /// written to `setter`.
    ///
    /// This can be used as an alternative to `DynamicProperty` for creating strongly typed
    /// bindings on Cocoa objects.
    ///
    /// N.B. Ensure that `self` isn't strongly captured by `initial` or `setter`, otherwise this
    /// will create a retain cycle causing `self` to never dealloc.
    public func rex_valueProperty<T>(key: UnsafePointer<()>, _ initial: () -> T, _ setter: T -> ()) -> MutableProperty<T> {
        return associatedObject(self, key: key) {
            let property = MutableProperty(initial())
            property.producer.start(next: setter)
            return property
        }
    }
}
