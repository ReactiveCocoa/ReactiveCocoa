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

// Creates a binding to the given key path.
//
// If given one argument, it's assumed to be a key path or property on self.
// If given two arguments, the first argument is the object to which the key
// path is relative to and the second one is the key path.
//
// If RACBind() is used on the left-hand side of an assignment and there is a
// RACBinding on the right-hand side of the assignment the two are subscribed to
// one another: the left-hand side property's value is set to the value of the
// property on the right-hand side and subsequent changes to one property will
// be reflected on the other.
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
@interface RACObservablePropertySubject : RACPropertySubject

// Returns a new RACPropertySubject wrapper for `keyPath` on `target` with a
// starting value equal to the value of `keyPath` on `target`.
+ (instancetype)propertyWithTarget:(NSObject *)target keyPath:(NSString *)keyPath;

@end

// Methods needed for the convenience macro. Do not call explicitly.
@interface RACObservablePropertySubject (RACBind)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)obj forKeyedSubscript:(id)key;

@end
