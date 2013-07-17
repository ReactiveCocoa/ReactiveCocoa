//
//  RACObservablePropertySubject.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject.h"
#import "EXTKeyPathCoding.h"
#import "metamacros.h"

// Creates a binding to the given key path. When the targeted object
// deallocates, the binding will complete.
//
// If RACBind() is used on the left-hand side of an assignment, there must a
// RACBinding on the right-hand side of the assignment. The two will be subscribed to
// one another: the left-hand side property's value is immediately set to the value of the
// property on the right-hand side, and subsequent changes to one property will
// be reflected on the other.
//
// There are two different versions of this macro:
//
//  - RACBind(TARGET, KEYPATH, NILVALUE) will create a binding to the `KEYPATH`
//    of `TARGET`. If the binding is ever sent a `nil` value, the property will be
//    set to `NILVALUE` instead. `NILVALUE` may itself be `nil` for object
//    properties, but an NSValue should be used for primitive properties, to
//    avoid an exception if `nil` is sent (which might occur if an intermediate
//    observee is set to `nil`).
//  - RACBind(TARGET, KEYPATH) is the same as the above, but `NILVALUE` defaults to
//    `nil`.
//
// Examples
//
//  RACBinding *objectBinding = RACBind(self, objectProperty);
//  RACBinding *integerBinding = RACBind(self, integerProperty, @42);
//
//  RACBind(self, objectProperty) = RACBind(otherObject, objectProperty);
//  RACBind(self, integerProperty, @2) = RACBind(otherObject, integerProperty, @10);
#define RACBind(TARGET, ...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RACBind_(TARGET, __VA_ARGS__, nil)) \
        (RACBind_(TARGET, __VA_ARGS__))

// Do not use this directly. Use the RACBind macro above.
#define RACBind_(TARGET, KEYPATH, NILVALUE) \
    [RACObservablePropertySubject propertyWithTarget:(TARGET) keyPath:@keypath(TARGET, KEYPATH) nilValue:(NILVALUE)][ @"binding" ]

// A RACPropertySubject wrapper for KVO compliant key paths.
//
// New values of `keyPath` will be sent to the wrapper's subscribers and its
// bindings' subscribers. `keyPath` will be updated with values sent to the
// wrapper or its bindings. Subscribers of the wrapper or its bindings will be
// sent the current value of `keyPath`.
//
// `completed` events sent to a RACObservablePropertySubject are also sent to
// its bindings' subscribers. `completed` events sent to
// a RACObservablePropertySubject's bindings are also sent to the
// RACObservablePropertySubject.
//
// It is considered undefined behavior to send `error` to
// a RACObservablePropertySubject or its bindings.
@interface RACObservablePropertySubject : RACPropertySubject

// Creates a new subject that will start with the current value of `keyPath` on
// `target`.
//
// target   - The object to observe and set.
// keyPath  - The key path on the `target`, to be observed and set.
// nilValue - The value to set at the key path whenever `nil` is sent to the
//            receiver. This may be nil when binding to object properties, but
//            an NSValue should be used for primitive properties, to avoid an
//            exception if `nil` is sent (which might occur if an intermediate
//            observee is set to `nil`).
//
// Returns a RACPropertySubject, or nil if an error occurs.
+ (instancetype)propertyWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue;

@end

@interface NSObject (RACObservablePropertySubjectDeprecated)

- (RACObservablePropertySubject *)rac_propertyForKeyPath:(NSString *)keyPath __attribute__((deprecated("Use +propertyWithTarget:keyPath:nilValue: instead")));

@end

// Methods needed for the convenience macro. Do not call explicitly.
@interface RACObservablePropertySubject (RACBind)

- (RACBinding *)objectForKeyedSubscript:(id)key;
- (void)setObject:(RACBinding *)obj forKeyedSubscript:(id)key;

@end
