//
//  Association.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Foundation
import ReactiveCocoa

/// Attaches a `MutableProperty` value to the `host` object using KVC to get the initial
/// value and write subsequent updates from the property's producer. Note that `keyPath`
/// is a `StaticString` because it's pointer value is used as key value when associating
/// the property.
///
/// This can be used as an alternative to `DynamicProperty` for creating strongly typed
/// bindings on Cocoa objects.
public func associatedProperty(host: AnyObject, keyPath: StaticString) -> MutableProperty<String> {
    // Workaround compiler warning when using keyPath.stringValue
    let key = "\(keyPath)"
    let initial: () -> String  = { [weak host] _ in
        host?.valueForKeyPath(key) as? String ?? ""
    }
    let setter: String -> () = { [weak host] newValue in
        host?.setValue(newValue, forKeyPath: key)
    }
    return associatedProperty(host, key: keyPath.utf8Start, initial: initial, setter: setter)
}

/// Attaches a `MutableProperty` value to the `host` object using KVC to get the initial
/// value and write subsequent updates from the property's producer. Note that `keyPath`
/// is a `StaticString` because it's pointer value is used as key value when associating
/// the property.
///
/// This can be used as an alternative to `DynamicProperty` for creating strongly typed
/// bindings on Cocoa objects.
///
/// N.B. Ensure that `host` isn't strongly captured by `placeholder`, otherwise this will
/// create a retain cycle with `host` causing it to never dealloc.
public func associatedProperty<T: AnyObject>(host: AnyObject, keyPath: StaticString, placeholder: () -> T) -> MutableProperty<T> {
    // Workaround compiler warning when using keyPath.stringValue
    let key = "\(keyPath)"
    let initial: () -> T  = { [weak host] _ in
        host?.valueForKeyPath(key) as? T ?? placeholder()
    }
    let setter: T -> () = { [weak host] newValue in
        host?.setValue(newValue, forKeyPath: key)
    }
    return associatedProperty(host, key: keyPath.utf8Start, initial: initial, setter: setter)
}

/// Attaches a `MutableProperty` value to the `host` object under `key`. The property is
/// initialized with the result of `initial`. Changes on the property's producer are
/// monitored and written to `setter`.
///
/// This can be used as an alternative to `DynamicProperty` for creating strongly typed
/// bindings on Cocoa objects.
///
/// N.B. Ensure that `host` isn't strongly captured by `initial` or `setter`, otherwise this
/// will create a retain cycle with `host` causing it to never dealloc.
public func associatedProperty<T>(host: AnyObject, key: UnsafePointer<()>, initial: () -> T, setter: T -> ()) -> MutableProperty<T> {
    return associatedObject(host, key: key) {
        let property = MutableProperty(initial())
        property.producer.start(next: setter)
        return property
    }
}

/// On first use attaches the object returned from `initial` to the `host` object using
/// `key` via `objc_setAssociatedObject`. On subsequent usage, returns said object via
/// `objc_getAssociatedObject`.
///
/// N.B. Ensure that `host` isn't strongly captured by `initial`, otherwise this will
/// create a retain cycle with `host` causing it to never dealloc.
public func associatedObject<T: AnyObject>(host: AnyObject, key: UnsafePointer<()>, initial: () -> T) -> T {
    var value = objc_getAssociatedObject(host, key) as? T
    if value == nil {
        value = initial()
        objc_setAssociatedObject(host, key, value, .OBJC_ASSOCIATION_RETAIN)
//        objc_setAssociatedObject(host, key, value, objc_AssociationPolicy())
    }
    return value!
}
