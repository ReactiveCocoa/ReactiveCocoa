//
//  Association.swift
//  Rex
//
//  Created by Neil Pankey on 6/19/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

/// Attaches a `MutableProperty` value to the `host` object using KVC to get the initial
/// value and write subsequent updates from the property's producer. Note that `keyPath`
/// is a `StaticString` because it's pointer value is used as key value when associating
/// the property.
///
/// This can be used as an alternative to `DynamicProperty` for creating strongly typed
/// bindings on Cocoa objects.
@warn_unused_result(message="Did you forget to use the property?")
public func associatedProperty(host: AnyObject, keyPath: StaticString) -> MutableProperty<String> {
    let initial: AnyObject -> String  = { host in
        host.valueForKeyPath(keyPath.stringValue) as? String ?? ""
    }
    let setter: (AnyObject, String) -> () = { host, newValue in
        host.setValue(newValue, forKeyPath: keyPath.stringValue)
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
@warn_unused_result(message="Did you forget to use the property?")
public func associatedProperty<T: AnyObject>(host: AnyObject, keyPath: StaticString, @noescape placeholder: () -> T) -> MutableProperty<T> {
    let setter: (AnyObject, T) -> () = { host, newValue in
        host.setValue(newValue, forKeyPath: keyPath.stringValue)
    }
    return associatedProperty(host, key: keyPath.utf8Start, initial: { host in
        host.valueForKeyPath(keyPath.stringValue) as? T ?? placeholder()
    }, setter: setter)
}

/// Attaches a `MutableProperty` value to the `host` object under `key`. The property is
/// initialized with the result of `initial`. Changes on the property's producer are
/// monitored and written to `setter`.
///
/// This can be used as an alternative to `DynamicProperty` for creating strongly typed
/// bindings on Cocoa objects.
@warn_unused_result(message="Did you forget to use the property?")
public func associatedProperty<Host: AnyObject, T>(host: Host, key: UnsafePointer<()>, @noescape initial: Host -> T, setter: (Host, T) -> (), @noescape setUp: MutableProperty<T> -> () = { _ in }) -> MutableProperty<T> {
    return associatedObject(host, key: key) { host in
        let property = MutableProperty(initial(host))

        setUp(property)

        property.producer.startWithNext { [weak host] next in
            if let host = host {
                setter(host, next)
            }
        }

        return property
    }
}

/// On first use attaches the object returned from `initial` to the `host` object using
/// `key` via `objc_setAssociatedObject`. On subsequent usage, returns said object via
/// `objc_getAssociatedObject`.
public func associatedObject<Host: AnyObject, T: AnyObject>(host: Host, key: UnsafePointer<()>, @noescape initial: Host -> T) -> T {
    var value = objc_getAssociatedObject(host, key) as? T
    if value == nil {
        value = initial(host)
        objc_setAssociatedObject(host, key, value, .OBJC_ASSOCIATION_RETAIN)
    }
    return value!
}
