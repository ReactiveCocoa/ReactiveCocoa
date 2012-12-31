//
//  RACKVOProperty.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
#import "EXTKeyPathCoding.h"
#import "metamacros.h"

// Convenience macro for creating bindings and binding them.
//
// If given just one argument, it's assumed to be a keypath or property on self.
// If given two, the first argument is the object to which the keypath is
// relative and the second is the keypath. If used as an rvalue returns a new
// binding. If used as an lvalue binds it with the lvalue, which must also be an
// instance of RACBinding.
//
// Examples:
// RACBinding *binding = RACBind(self.property);
// RACBind(self.property) = RACBind(otherObject, property);
#define RACBind(...) metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(_RACBindObject(self, __VA_ARGS__))(_RACBindObject(__VA_ARGS__))

// Do not use this directly. Use the RACBind macro above.
#define _RACBindObject(OBJ, KEYPATH) [RACKVOProperty propertyWithTarget:OBJ keyPath:@keypath(OBJ, KEYPATH)][ @"dummy-key" ]

// A signal / subscriber interface wrapper for KVC compliant properties.
//
// Send values to it to update the value of `keyPath` on `target`. Subscribers
// are sent the current value of `keyPath` on `target` on subscription, and new
// values as it changes.
@interface RACKVOProperty : RACProperty

// Returns a property interface to `keyPath` on `target`.
+ (instancetype)propertyWithTarget:(id)target keyPath:(NSString *)keyPath;

// Method needed for the convenience macro. Do not call explicitly.
- (id)objectForKeyedSubscript:(id)key;

// Method needed for the convenience macro. Do not call explicitly.
- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

@end
