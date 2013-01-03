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
#define _RACBindObject(OBJ, KEYPATH) [RACKVOProperty propertyWithTarget:OBJ keyPath:@keypath(OBJ, KEYPATH)][ @"binding" ]

// A RACProperty wrapper for KVO compliant key paths.
//
// New values of `keyPath` will be sent to the wrapper's subscribers and it's
// bindings' subscribers. `keyPath` will be updated with values sent to the
// wrapper or it's bindings. Subscribers of the wrapper or it's bindings will be
// sent the current value of `keyPath`.
@interface RACKVOProperty : RACProperty

// Returns a new RACProperty wrapper for `keyPath` on `target` with a starting
// value equal to the value of `keyPath` on `target`.
+ (instancetype)propertyWithTarget:(id)target keyPath:(NSString *)keyPath;

// Method needed for the convenience macro. Do not call explicitly.
- (id)objectForKeyedSubscript:(id)key;

// Method needed for the convenience macro. Do not call explicitly.
- (void)setObject:(id)obj forKeyedSubscript:(id)key;

@end
