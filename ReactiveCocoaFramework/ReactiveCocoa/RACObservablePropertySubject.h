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

// Convenience macro for creating bindings and binding them.
//
// If given just one argument, it's assumed to be a keypath or property on self.
// If given two, the first argument is the object to which the keypath is
// relative and the second is the keypath.
//
// If RACBind() is used as an lvalue (an assignee), the named property is bound
// to the RACBinding provided on the right-hand side of the assignment. The
// binding property's value is set to the value of the property being bound to,
// then any changes to one property will be reflected on the other.
//
// If RACBind() is used as an rvalue, a RACBinding is returned.
//
// Examples:
// RACBinding *binding = RACBind(self.property);
// RACBind(self.property) = RACBind(otherObject, property);
#define RACBind(...) metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(_RACBindObject(self, __VA_ARGS__))(_RACBindObject(__VA_ARGS__))

// Do not use this directly. Use the RACBind macro above.
#define _RACBindObject(OBJ, KEYPATH) [RACObservablePropertySubject propertyWithTarget:OBJ keyPath:@keypath(OBJ, KEYPATH)][ @"binding" ]

// A RACPropertySubject wrapper for KVO compliant key paths.
//
// New values of `keyPath` will be sent to the wrapper's subscribers and it's
// bindings' subscribers. `keyPath` will be updated with values sent to the
// wrapper or it's bindings. Subscribers of the wrapper or it's bindings will be
// sent the current value of `keyPath`.
//
// Note: RACObservablePropertySubject is not thread-safe and should not observe
// a property, or be bound to a RACProperty, whose value can be changed from
// multiple threads at the same time.
@interface RACObservablePropertySubject : RACPropertySubject

// Returns a new RACPropertySubject wrapper for `keyPath` on `target` with a
// starting value equal to the value of `keyPath` on `target`.
+ (instancetype)propertyWithTarget:(id)target keyPath:(NSString *)keyPath;

@end

// Methods needed for the convenience macro. Do not call explicitly.
@interface RACObservablePropertySubject (RACBind)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)obj forKeyedSubscript:(id)key;

@end
